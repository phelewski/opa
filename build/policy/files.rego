# Expects policy input as provided by:
# https://api.github.com/repos/open-policy-agent/opa/pulls/${PR_ID}/files
#
# Note that the "filename" here refers to the full path of the file, like
# docs/website/data/integrations.yaml - since that's how it's named in the
# input we'll use the same convention here.

package files

import future.keywords.in

import data.helpers.endswith_any
import data.helpers.last_indexof

filenames := {f.filename | some f in input}

changes := {filename: attributes |
	some change in input
	filename := change.filename
	attributes := object.remove(change, ["filename"])
}

get_file_in_pr(filename) = http.send({"url": changes[filename].raw_url, "method": "GET"}).raw_body

deny["Logo must be placed in docs/website/static/img/logos/integrations"] {
	"docs/website/data/integrations.yaml" in filenames

	some filename in filenames
	endswith(filename, ".png")
	changes[filename].status == "added"
	directory := substring(filename, 0, last_indexof(filename, "/"))
	directory != "docs/website/static/img/logos/integrations"
}

deny["Logo must be a .png file"] {
	"docs/website/data/integrations.yaml" in filenames

	some filename in filenames
	changes[filename].status == "added"
	directory := substring(filename, 0, last_indexof(filename, "/"))
	directory == "docs/website/static/img/logos/integrations"
	not endswith(filename, ".png")
}

# Helper rule to work around not being able to mock functions yet
yaml_file_contents := {filename: get_file_in_pr(filename) |
	some filename in filenames
	endswith_any(filename, [".yml", ".yaml"])
}

deny[sprintf("%s is an invalid YAML file", [filename])] {
	some filename, content in yaml_file_contents
	changes[filename].status in {"added", "modified"}
	not yaml.is_valid(content)
}
