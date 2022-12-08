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

* `daily_storage.sh` --- Show $FWDIR/log disk space use by traffic logs per day.
