# Skyline deployment and configuration scripts

The scripts in this directory are used to deploy and configure Check Point Skyline.
They have these dependencies:

* <https://github.com/vbrozik/vb-shell-tools/blob/main/scripts/file_formats/rfc7468_to_single_line.sh>

For convenience the directory contains a symlink to rfc7468_to_single_line.sh for the case
the vb-shell-tools repository is in an adjacent directory to the directory of this repository.

## Deployment

The configuration files have to be kept in a dedicated directory. Here it is `config_example`.
The files in the repository must keep their original names. Other files will be ignored.

Edit `skyline_config_template.json`. Replace these placeholders with your values and possibly modify other parameters:

* `{{username}}`
* `{{password}}`
* `{{address}}`

The directory must contain the following files which are filled by example content in this repository:

* `skyline_config_template.json` - the main configuration file template
* `certificate.pem` - the certificate file in PEM format

## TODO

Replace `cert.pem` with an actual example certificate in PEM format. The current file contains just
a PEM-like garbage.
