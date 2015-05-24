# Wrapper around wrapPythonProgramsIn, below. The $pythonPath
# variable is passed in from the buildPythonPackage function.
wrapPythonPrograms() {
    wrapPythonProgramsIn $out "$out $pythonPath"
}

# Transforms any binaries generated by the setup.py script, replacing them
# with an executable shell script which will set some environment variables
# and then call into the original binary (which has been given a .wrapped
# suffix).
wrapPythonProgramsIn() {
    local dir="$1"
    local pythonPath="$2"
    local python="@executable@"
    local path
    local f

    # Create an empty table of python paths (see doc on _addToPythonPath
    # for how this is used). Build up the program_PATH and program_PYTHONPATH
    # variables.
    declare -A pythonPathsSeen=()
    program_PYTHONPATH=
    program_PATH=
    for path in $pythonPath; do
        _addToPythonPath $path
    done

    # Find all regular files in the output directory that are executable.
    for f in $(find "$dir" -type f -perm +0100); do
        # Rewrite "#! .../env python" to "#! /nix/store/.../python".
        if head -n1 "$f" | grep -q '#!.*/env.*\(python\|pypy\)'; then
            sed -i "$f" -e "1 s^.*/env[ ]*\(python\|pypy\)^#! $python^"
        fi

        # catch /python and /.python-wrapped
        if head -n1 "$f" | grep -q '/\.\?\(python\|pypy\)'; then
            # dont wrap EGG-INFO scripts since they are called from python
            if echo "$f" | grep -qv EGG-INFO/scripts; then
                echo "wrapping \`$f'..."
                sed -i "$f" -re '@magicalSedExpression@'
                # wrapProgram creates the executable shell script described
                # above. The script will set PYTHONPATH and PATH variables.!
                # (see pkgs/build-support/setup-hooks/make-wrapper.sh)
                local wrap_args="$f \
                                 --prefix PYTHONPATH ':' $program_PYTHONPATH \
                                 --prefix PATH ':' $program_PATH"

                # Add any additional arguments provided by makeWrapperArgs
                # argument to buildPythonPackage.
                for arg in $makeWrapperArgs; do
                    wrap_args="$wrap_args $arg"
                done
                wrapProgram $wrap_args
            fi
        fi
    done
}

# Adds the lib and bin directories to the PYTHONPATH and PATH variables,
# respectively. Recurses on any paths declared in
# `propagated-native-build-inputs`, while avoiding duplicating paths by
# flagging the directories it has visited in `pythonPathsSeen`.
_addToPythonPath() {
    local dir="$1"
    # Stop if we've already visited here.
    if [ -n "${pythonPathsSeen[$dir]}" ]; then return; fi
    pythonPathsSeen[$dir]=1
    # addToSearchPath is defined in stdenv/generic/setup.sh. It will have
    # the effect of calling `export program_X=$dir/...:$program_X`.
    addToSearchPath program_PYTHONPATH $dir/lib/@libPrefix@/site-packages
    addToSearchPath program_PATH $dir/bin

    # Inspect the propagated inputs (if they exist) and recur on them.
    local prop="$dir/nix-support/propagated-native-build-inputs"
    if [ -e $prop ]; then
        local new_path
        for new_path in $(cat $prop); do
            _addToPythonPath $new_path
        done
    fi
}

createBuildInputsPth() {
    local category="$1"
    local inputs="$2"
    if [ foo"$inputs" != foo ]; then
        for x in $inputs; do
            if $(echo -n $x |grep -q python-recursive-pth-loader); then
                continue
            fi
            if test -d "$x"/lib/@libPrefix@/site-packages; then
                echo $x/lib/@libPrefix@/site-packages \
                    >> "$out"/lib/@libPrefix@/site-packages/${name}-nix-python-$category.pth
            fi
        done
    fi
}
