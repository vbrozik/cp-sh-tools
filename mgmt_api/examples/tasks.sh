#!/bin/sh

# Get overview of failed tasks (like policy install):

mgmt_cli -r true show tasks status failed details-level full --format json |
    jq '[
            .tasks[]
            | select(."task-name" | contains("Policy installation - czobl_policy"))
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
                            gatewayId: $task_details.gatewayId,
                            stage: $stage.stage,
                            message
                            }
                    ]
            } | select(.["error-messages"] | length > 0)
        ] | sort_by(.["creation-time-iso"])'

mgmt_cli -r true show tasks status failed details-level full --format json |
    jq '[
            .tasks[]
            | select(."task-name" | contains("Policy installation - czobl_policy"))
        ] | sort_by(.["creation-time-iso"])'

# TODO: Dictionary of gateways UID -> name
# fails:
# show objects type CpmiVsClusterMember
