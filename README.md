# Check Point shell tools

Shell tools for various tasks on Check Point products.

## `unused_objects`

* `del_unused_gen.sh` --- Generate lists of unused object UUIDs by type to be used for later deletion.
* `del_unused_del.sh` --- Delete objects from given lists.

### Usage

```sh
del_unused_gen.sh
```

Creates numbered directories `del_list-nnnnnn`. Directories contain UUIDs of unused objects, sorted into files by object type. `list.json` contains all the unused objects with details. By default new directory is created for every 500 objects.

```sh
del_unused_del.sh del_list-000000
```

Shows commands which will be executed to perform the deletion. No changes are made.

```sh
del_unused_del.sh --del del_list-000000
```

Performs the deletions of the objects.

## `logs`

* `daily_storage.sh` --- Show `$FWDIR/log` disk space use by traffic logs per day.

### log_archive_upload

This script archives and uploads logs from a log server on Gaia to another machine using SFTP. It is designed to be run every day using `cron`. Logs from each day are stored to a tar gz archive and then uploaded. The archives are named `DATE_HOSTNAME.tgz`. DATE is the date of the logs in ISO format, HOSTNAME is the hostname of the log server machine the logs are archived and uploaded from.

* `/var/log/log_arch` --- working directory
  * `tmp/` --- In this directory the archive file is created and after upload it is removed. After the script finishes without crash the directory should be empty.
  * `log_arch.log` --- log file of the tool
  * `last_dates.txt` --- last dates uploaded. The tool uploads dates after the last date uploaded and by default logs older than from yesterday.

#### log_archive_upload usage

Configure public-key based authentication for SSH so that `admin` can connect from the Gaia machine to the target server without entering a password. Do the rest of the configuration for `admin` too.

Copy the script `log_archive_upload.sh` to a directory by your choice. It could be a subdirectory in `/opt`. Make the script executable. Configure the script by creating `log_archive_upload_conf.sh` in the same directory. Set the parameters in the configuration file. Usually it will be just two parameters for SFTP uploads:

``` bash
upload_dir=/directory/on_the_target/machine
upload_target=username@hostname
```

Configure the cron job in clish (Gaia allows configuring cron jobs for `admin`). Use time parameters of your choice.

``` clish
add cron job log_arch command "/your_directory/log_archive_upload.sh recurrence daily time 2:25"
```

When executed the script checks log days suitable for upload. For each days it creates an archive, uploads it with suffix `.incomplete`. After the upload finishes successfully the suffix is removed and the day is marked as processed (to not upload it repeatedly).

### cloud_uploader

This is a script which uploads available files to AWS S3 and deletes them afterwards. It is designed to cooperate with `log_archive_upload` running on Gaia. When executed it checks the given incoming directory for files with a given suffix (`.incomplete` files are ignored). All matching files are then uploaded to än AWS S3 bucket.

Similarly to the other script `cloud_uploader_conf.sh` is a configuration file.

## Conventions

The shell scripts for normal use have no suffix so that they can be called by their plain names. (Old scripts may have `.sh` or `.bash` suffixes until they are fixed.) Shell library files have `.sh` or `.bash` suffix, they are not in PATH and they do not have the executable bit set.

Shell scripts for special use like `install.bash` have a suffix.

The shebang line is used in all shell files so that text editors and file content detection correctly recognize the files as containing shell code.
