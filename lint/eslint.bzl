"Public API re-exports"

load("@aspect_bazel_lib//lib:copy_to_bin.bzl", "copy_files_to_bin_actions")
load("@aspect_rules_js//js:libs.bzl", "js_lib_helpers")

def _eslint_action(ctx, executable, srcs, report, diff_file, use_exit_code = False):
    """Create a Bazel Action that spawns an eslint process.

    Adapter for wrapping Bazel around
    https://eslint.org/docs/latest/use/command-line-interface

    Args:
        ctx: an action context OR aspect context
        executable: struct with an eslint field
        srcs: list of file objects to lint
        report: output to create
        use_exit_code: whether an eslint process exiting non-zero will be a build failure
    """

    args = ctx.actions.args()

    # require explicit path to the eslintrc file, don't search for one
    args.add("--no-eslintrc")
    args.add("--fix")

    # TODO: enable if debug config, similar to rules_ts
    # args.add("--debug")

    args.add(ctx.file._config_file.short_path, format = "--config=%s")
    args.add(report.short_path, format = "--output-file=%s")
    args.add_all([s.short_path for s in srcs])

    env = {
        "BAZEL_BINDIR": ctx.bin_dir.path,
        "DIFF_PATH": diff_file.short_path,
    }

    inputs = copy_files_to_bin_actions(ctx, srcs)

    # Add the config file along with any deps it has on npm packages
    inputs.extend(js_lib_helpers.gather_files_from_js_providers(
        [ctx.attr._config_file],
        include_transitive_sources = True,
        include_declarations = False,
        include_npm_linked_packages = True,
    ).to_list())

    outputs = [report, diff_file]

    if not use_exit_code:
        exit_code_out = ctx.actions.declare_file("exit_code_out")
        outputs.append(exit_code_out)
        env["JS_BINARY__EXIT_CODE_OUTPUT_FILE"] = exit_code_out.path

    ctx.actions.run(
        inputs = inputs,
        outputs = outputs,
        executable = executable._eslint,
        arguments = [args],
        env = env,
        mnemonic = "ESLint",
    )

# buildifier: disable=function-docstring
def _eslint_aspect_impl(target, ctx):
    if ctx.rule.kind in ["ts_project_rule"]:
        report = ctx.actions.declare_file(target.label.name + ".eslint-report.txt")
        diff_file = ctx.actions.declare_file(target.label.name + ".eslint.diff")

        _eslint_action(ctx, ctx.executable, ctx.rule.files.srcs, report, diff_file)

        results = depset([report])
        diffs = depset([diff_file])
    else:
        results = depset()
        diffs = depset()

    return [
        OutputGroupInfo(report = results, diffs = diffs),
    ]

def eslint_aspect(binary, config):
    """A factory function to create a linter aspect.
    """
    return aspect(
        implementation = _eslint_aspect_impl,
        # attr_aspects = ["deps"],
        attrs = {
            "_eslint": attr.label(
                default = binary,
                executable = True,
                cfg = "exec",
            ),
            "_config_file": attr.label(
                default = config,
                allow_single_file = True,
            ),
        },
    )
