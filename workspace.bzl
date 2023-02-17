def _rules_helm_dependencies_impl(ctx):
    cmd = ctx.execute([
        "rsync",
        "-r",
        "--delete-before",
        "../%s/%s/" % (ctx.attr.repository, ctx.attr.chart_path),
        ".",
    ])
    cmd = ctx.execute([
        "helm",
        "dependency",
        "update",
        ".",
    ])
    ctx.file("BUILD.bazel", content="""load("@com_github_tomsons_rules_helm//:chart.bzl", "chart")
filegroup(
    name = "sources",
    srcs = glob(["**/*"], exclude = ["BUILD.bazel", "WORKSPACE", "templates/tests/**/*"]),
    visibility = ["//visibility:public"],
)
chart(
    name = "chart",
    chart_name = "{name}",
    srcs = [":sources"],
    visibility = ["//visibility:public"],
)
    """.format(
            name = ctx.name,
        )
    )
    ctx.file("WORKSPACE", content='')

rules_helm_dependencies = repository_rule (
    implementation = _rules_helm_dependencies_impl,
    attrs = {
        "repository": attr.string(mandatory = True),
        "chart_path": attr.string(mandatory = True),
    },
)