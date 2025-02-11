#!/bin/sh

# Get overview of failed tasks (like policy install):

mgmt_cli -r true show tasks status failed details-level full --format json |
    jq '[
            .tasks[]
            | {
                "task-name",
                "creation-time-iso": ."meta-info"."creation-time"."iso-8601",
                "last-modify-time-iso": ."meta-info"."last-modify-time"."iso-8601",
                "error-messages": [
                    .["task-details"][]?
                        | . as $task_details
                        | .stagesInfo[]?
                        | select(.type=="err")
                        | . as $stage
                        | .messages[]?
                        | select(.type=="err")
                        | {
                            "creation-time-iso": $task_details["meta-info"]["creation-time"]["iso-8601"],
                            "last-modify-time-iso": $task_details["meta-info"]["last-modify-time"]["iso-8601"],
                            "stage": $stage.stage,
                            "message": .message
                            }
                    ]
            } | select(.["error-messages"] | length > 0)
        ] | sort_by(.["creation-time-iso"])'
