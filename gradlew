#!/usr/bin/env bash

## 
## Tries to recreate Gradle's gradlew command in pure bash.
## This way you don't have to worry about binaries in your build.
##

set -e
set -o pipefail

# Add default JVM options here. You can also use JAVA_OPTS and GRADLE_OPTS to pass JVM options to this script.
DEFAULT_JVM_OPTS=""

APP_NAME="Gradle"
APP_BASE_NAME=`basename "$0"`

bin=`dirname "$0"`
bin=`cd "$bin">/dev/null; pwd`

. "$bin/gradle/wrapper/gradle-wrapper.properties"

warn ( ) {
    echo "$*"
}

die ( ) {
    echo
    echo "$*"
    echo
    exit 1
}

# OS specific support (must be 'true' or 'false').
darwin=false
case "`uname`" in
  Darwin* )
    darwin=true
    ;;
esac

# Determine the Java command to use to start the JVM.
if [ -n "$JAVA_HOME" ] ; then
    if [ -x "$JAVA_HOME/jre/sh/java" ] ; then
        # IBM's JDK on AIX uses strange locations for the executables
        JAVA="$JAVA_HOME/jre/sh/java"
    else
        JAVA="$JAVA_HOME/bin/java"
    fi
    if [ ! -x "$JAVA" ] ; then
        die "ERROR: JAVA_HOME is set to an invalid directory: $JAVA_HOME

Please set the JAVA_HOME variable in your environment to match the
location of your Java installation."
    fi
else
    JAVA="java"
    which java >/dev/null 2>&1 || die "ERROR: JAVA_HOME is not set and no 'java' command could be found in your PATH.

Please set the JAVA_HOME variable in your environment to match the
location of your Java installation."
fi

# Increase the maximum file descriptors if we can.
if [ "$darwin" = "false" ] ; then
    MAX_FD_LIMIT=`ulimit -H -n`
    if [ $? -eq 0 ] ; then
        if [ "$MAX_FD" = "maximum" -o "$MAX_FD" = "max" ] ; then
            MAX_FD="$MAX_FD_LIMIT"
        fi
        ulimit -n $MAX_FD
        if [ $? -ne 0 ] ; then
            warn "Could not set maximum file descriptor limit: $MAX_FD"
        fi
    else
        warn "Could not query maximum file descriptor limit: $MAX_FD_LIMIT"
    fi
fi

# For Darwin, add options to specify how the application appears in the dock
if $darwin; then
    GRADLE_OPTS="$GRADLE_OPTS \"-Xdock:name=$APP_NAME\" \"-Xdock:icon=$bin/media/gradle.icns\""
fi

# does not match gradle's hash
# waiting for http://stackoverflow.com/questions/26642077/java-biginteger-in-bash-rewrite-gradlew
hash() {
  local input="$1"
  if $darwin; then
    md5 -q -s "$1"
  else
    echo -n "$1" | md5sum  | cut -d" " -f1
  fi
}

dist_path() {
  local dir=$(basename $distributionUrl | sed 's;.zip;;g')
  local id=$(hash "$distributionUrl")

  echo "$HOME/.gradle/wrapper/dists/$dir/$id"
}

download() {
  local base_path=$(dist_path)
  local file_name=$(basename $distributionUrl)
  local dir_name=$(echo "$file_name" | sed 's;-bin.zip;;g' | sed 's;-src.zip;;g' |sed 's;-all.zip;;g')

  if [ ! -d "$base_path" ]; then
    mkdir -p "$base_path"
  fi

  # download dist. curl on mac doesn't like the cert provided...
  curl --insecure -L -o "$base_path/$file_name" "$distributionUrl"

  pushd "$base_path"
    touch "$file_name.lck"
    unzip "$file_name" 1> /dev/null
    pushd "$dir_name/lib"
      # gradle wrapper requires this file to be top level in classpath
      unzip gradle-core-*.jar org/gradle/build-receipt.properties
      mv org/gradle/build-receipt.properties .
      rm -rf org/
      # gradle wrapper finds the jar it was loaded from, and uses the path
      # to find the properties file. 
      # copy it into the project so it shows up
      # symlink won't show up for the function
      cp gradle-wrapper-*.jar $bin/gradle/wrapper/gradle-wrapper.jar
    popd
    touch "$file_name.ok"
  popd
}

is_cached() {
  local file_name=$(basename $distributionUrl)

  [ -e "$(dist_path)/$file_name.ok" ]
}

lib_path() {
  local base_path=$(dist_path)
  local file_name=$(basename $distributionUrl | sed 's;-bin.zip;;g' | sed 's;-src.zip;;g' |sed 's;-all.zip;;g')

  echo "$base_path/$file_name/lib"
}

classpath() {
  local dir=$(lib_path)
  local cp=$(ls -1 $dir/*.jar | tr '\n' ':')
  echo "$dir:$cp"
}

# Split up the JVM_OPTS And GRADLE_OPTS values into an array, following the shell quoting and substitution rules
function splitJvmOpts() {
  JVM_OPTS=("$@")
}

main() {
  if ! is_cached; then
    download
  fi

  eval splitJvmOpts $DEFAULT_JVM_OPTS $JAVA_OPTS $GRADLE_OPTS
  JVM_OPTS[${#JVM_OPTS[*]}]="-Dorg.gradle.appname=$APP_BASE_NAME"

  #TODO find if there is a way to bypass the wrapper code completely
  $JAVA "${JVM_OPTS[@]}" -cp $bin/gradle/wrapper/gradle-wrapper.jar:$(classpath) org.gradle.wrapper.GradleWrapperMain "$@"
}

main "$@"
