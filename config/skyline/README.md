# Skyline deployment and configuration scripts

The scripts in this directory are used to deploy and configure Check Point Skyline.
They currently support Skyline using the Prometheus database remote-write API integration as described in the Check Point documentation.

They have these dependencies:

* <https://github.com/vbrozik/vb-shell-tools/blob/main/scripts/file_formats/rfc7468_to_single_line.sh>

For convenience the directory contains a symlink to rfc7468_to_single_line.sh for the case
the vb-shell-tools repository is in an adjacent directory to the directory of this repository.

## Deployment

### Configuration files

The configuration files have to be kept in a dedicated directory. Here it is `config_example`.
The files in the repository must keep their original names. Other files will be ignored.

It is recommended to copy the `config_example` directory to a directory of your choice and make the required edits there.

The directory must contain the following files which are filled by example content in this repository:

* `skyline_config_template.json` - the main configuration file template
* `certificate.pem` - the certificate file in PEM format containing the public certificate of the Prometheus database remote-write API endpoint
* `no_proxy` - optional file containing a comma-separated list of addresses that should bypass the HTTP proxy configured in Gaia, if not present the HTTP proxy will be used for all addresses
* `environment_label` - optional file with the environment label (a value for the label 'environment' to be added to the exported metrics)

Edit `skyline_config_template.json`. Replace the placeholders listed below with your values and possibly modify other parameters:

* Prometheus database remote-write API access parameters
  * `{{username}}`
  * `{{password}}`
  * `{{address}}`

The other placeholders must not be changed in the configuration file unless you know what you are doing and you want to supply your static values. The installation script will replace the placeholders with the actual values during deployment.

* `{{certificate}}` - the placeholder for the public certificate of the Prometheus database remote-write API endpoint
* `{{action}}` - the placeholder for the action of the Skyline deployment

## TODO

Replace `cert.pem` with an actual example certificate in PEM format. The current file contains just
a PEM-like garbage.
