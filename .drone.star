load("@common//:steps.star", "notify_author")
load("@common//:utils.star", "ECR_URL", "retrieve_parameter")

def main(ctx):
    return [
        retrieve_parameter("DRONE_SLACK_BOT_TOKEN"),
        retrieve_parameter("DRONE_PEOPLEFORCE_API_KEY"),
        build_pipeline(ctx),
    ]

def build_pipeline(ctx):
    return {
        "kind": "pipeline",
        "name": "build and push drone ecr image",
        "steps": [
            {
                "name": "build-push",
                "image": "golang:1.17.3",
                "commands": [
                    "go build -v -ldflags \"-X main.version=${DRONE_COMMIT_SHA:0:8}\" -a -tags netgo -o release/linux/amd64/drone-docker ./cmd/drone-docker",
                    "go build -v -ldflags \"-X main.version=${DRONE_COMMIT_SHA:0:8}\" -a -tags netgo -o release/linux/amd64/drone-ecr ./cmd/drone-ecr",
                ],
                "environment": {
                    "CGO_ENABLED": 0,
                    "GO111MODULE": "on"
                },
            },
            generate_tags_file(ctx),
            {
                "name": "build and push drone ecr image",
                "image": "plugins/ecr",
                "settings": {
                    "registry": ECR_URL,
                    "repo": "drone-plugin/ecr",
                    "dockerfile": "docker/ecr/Dockerfile.linux.amd64",
                    "custom_dns": "169.254.169.253",
                    "auto_tag": "true",
                },
            },
            notify_author(
                {"from_secret": "drone_slack_bot_token"},
                {"from_secret": "drone_peopleforce_api_key"},
            ),
        ],
        "trigger": {
            "branch": ["master"],
            "event": ["push"],
        },
    }

def generate_tags_file(ctx):
    commit_sha = ctx.build.commit[:6]

    return {
        "name": "generate tags file",
        "image": "alpine:3.11.5",
        "commands": [
            'echo -n "$(cat version),$DRONE_BUILD_NUMBER,latest,{}" > .tags'.format(commit_sha),
        ],
    }
