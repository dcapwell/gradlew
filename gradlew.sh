#!/usr/bin/env bash

## 
## Tries to recreate Gradle's gradlew command in pure bash.
## This way you don't have to worry about binaries in your build.
##

set -e
set -o pipefail

bin=`dirname "$0"`
bin=`cd "$bin">/dev/null; pwd`

. "$bin/gradle/wrapper/gradle-wrapper.properties"

JAVA="/System/Library/Java/JavaVirtualMachines/1.6.0.jdk/Contents/Home/bin/java"

# does not match gradle's hash
# waiting for http://stackoverflow.com/questions/26642077/java-biginteger-in-bash-rewrite-gradlew
hash() {
  local input="$1"
  md5 -q -s "$1"
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

main() {
  if ! is_cached; then
    download
  fi

  # echo $bin/gradle/wrapper/gradle-wrapper.jar:$(classpath) 
  $JAVA -cp $bin/gradle/wrapper/gradle-wrapper.jar:$(classpath) org.gradle.wrapper.GradleWrapperMain "$@"
}

main "$@"
