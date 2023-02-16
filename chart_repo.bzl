load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")

def chart_repo(
    name = "",
    remote = "",
    commit = "",
    shallow_since = "",
    path_prefix = "",
    charts = [],
    ):
    build_file_contents = ""
    for chart in charts:
        path = []
        if path_prefix != "":
            path.append(path_prefix)
        path.append(chart)
        build_file_contents += """
filegroup(
    name = "{chart_name}",
    srcs = glob(["{path_prefix}/**/*"], exclude = ["{path_prefix}/templates/tests/**/*"]),
    visibility = ["//visibility:public"],
)""".format(chart_name = chart, path_prefix = "/".join(path))
    new_git_repository(
        name = name,
        remote = remote,
        commit = commit,
        shallow_since = shallow_since,
        build_file_content = build_file_contents,
    )