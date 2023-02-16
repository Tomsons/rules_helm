load(":providers.bzl", "ConfigMapInfo", "ChartInfo")

def _strip_path(files):
    for f in files:
        if f.basename == "Chart.yaml":
            return f.path.replace(f.basename, "")

def _compute_substitutions(ctx, extraSubs):
    subs = extraSubs
    for (k, v) in ctx.attr.substitutions.items():
        subs[k] = v
    if "%{name}" not in subs:
        subs["%{name}"] = ctx.label.name
    return subs

def _dump_self_shell(ctx):
    self = ctx.actions.declare_file("self.sh")
    ctx.actions.write(
        self,
        """#!/bin/bash
echo -n {genfiles_dir}/{dir}
    """.format(genfiles_dir = ctx.genfiles_dir.path, dir = ctx.label.package),
        is_executable = True
    )
    return self

def _gen_configmaps(ctx, chart_name):
    outs = []
    maps_subs = "configMaps:"
    for c in ctx.attr.configmaps:
        for f in c[ConfigMapInfo].srcs:
            suffix = f.basename\
                .replace(".", "-")\
                .replace("_", "-")\
                .lower()
            configmap_name = "{{ include \"%s.fullname\" . }}-%s" % (chart_name, suffix)
            map = ctx.actions.declare_file("templates/configmaps/%s.yaml" % f.basename.replace(".", "_"))
            contents = """---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {chart_fullname}
  labels:
    {chart_labels}
data:""".format(
                chart_fullname = configmap_name,
                chart_labels = "{{- include \"%s.labels\" . | nindent 4 }}" % chart_name,
            )
            out = ctx.actions.declare_file("files/%s" % f.basename)
            ctx.actions.expand_template(template = f, output = out, substitutions = c[ConfigMapInfo].substitutions)
            outs.append(out)
            contents += """
  {file_name}: |
    {get_file}""".format(
                file_name = f.basename,
                get_file = "{{ .Files.Get \"files/%s\" . | nindent 4}}" % (f.basename)
            )
            ctx.actions.write(map, contents)
            expand_path = "/" + ctx.label.package
            if c[ConfigMapInfo].expand_path != "":
                expand_path = c[ConfigMapInfo].expand_path
            maps_subs += """
  - name: {name}
    expandPath: {expand_path}
    key: {key}""".format(
                key = f.basename,
                name = "\"%s\"" % configmap_name.replace("\"", "\\\""),
                expand_path = expand_path
            )
            outs.append(map)
    return struct (
        outputs = outs,
        substitutions = maps_subs
    )

def _chart(ctx):
    outs = []
    strip_path = _strip_path(ctx.files.srcs)
    subs = _compute_substitutions(ctx, {})
    files = {}
    for f in ctx.files.srcs:
        path = f.path.replace(strip_path, "").replace(ctx.label.package + "/", "")
        files[path] = f
    for (path, file) in files.items():
        out = ctx.actions.declare_file(path)
        if path.endswith(".tgz"):
            ctx.actions.run_shell(
                inputs = [file],
                outputs = [out],
                command = "cp {file} {out}".format(file = file.path, out = out.path)
            )
        else:
            ctx.actions.expand_template(template = file, output = out, substitutions = subs)
        outs.append(out)
        files[path] = out
    for d in ctx.attr.deps:
        chart_info = d[ChartInfo]
        for (path, file) in d[ChartInfo].srcs.items():
            out_path = "/".join(["charts", chart_info.name, path])
            out = ctx.actions.declare_file(out_path)
            ctx.actions.run_shell(
                inputs = [file],
                outputs = [out],
                command = "mkdir -p {dir} && cp {file} {out}".format(dir = out.dirname, file = file.path, out = out.path)
            )
            outs.append(out)
            files[out_path] = out
    return [
        DefaultInfo (
            files = depset(outs),
            executable = _dump_self_shell(ctx)
        ),
        ChartInfo (
            name = ctx.label.package.split("/").pop(),
            srcs = files,
        ),
    ]

def _configmap(ctx):
    return ConfigMapInfo (
        srcs = ctx.files.srcs,
        name = "%s.yaml" % ctx.label.name,
        substitutions = ctx.attr.substitutions,
        expand_path = ctx.attr.expand_path,
    )

chart = rule (
    implementation = _chart,
    executable = True,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
        "substitutions": attr.string_dict(default = {}),
        "configmaps": attr.label_list(providers = [ConfigMapInfo]),
        "deps": attr.label_list(default = [], providers = [ChartInfo])
    }
)

configmap = rule (
    implementation = _configmap,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
        "substitutions": attr.string_dict(default = {}),
        "expand_path": attr.string(default = ""),
    }
)