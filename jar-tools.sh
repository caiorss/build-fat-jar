#!/usr/bin/env sh
#
# Tool to build Java fat jar bundling all java dependencies with
# the application. It is useful to deploy and build the application.
#
#
#
#--------------------------------------------------------------



if [ "$DEBUG" = "true" ]
then
    set -x
fi


SCALA_LIB_PATH=$(realpath $(dirname $(which scala))/../lib)
SCALA_RUNTIME=$SCALA_LIB_PATH/scala-library.jar


case "$1" in

    # Display jar file manifest
    -jar-manifest)
        unzip -p $2 META-INF/MANIFEST.MF
        ;;

    -jar-main)
        unzip -p $2 META-INF/MANIFEST.MF | grep -i 'Main-Class'
        ;;

    -jar-view)
        jar -tfv $2
        ;;

    # Convert fat-jar jar to executable jar with .sh extension
    -jar-to-sh)
        INPUT_JAR=$2
        OUTPUT_SH=$3
        cat <<EOF > $OUTPUT_SH
#!/usr/bin/env sh
java -jar \$0 \$@
exit 0
EOF
        cat $INPUT_JAR >> $OUTPUT_SH
        chmod +x $OUTPUT_SH

        echo "Build jar-executable $OUTPUT_SH"
        echo "Run it with ./$OUTPUT_SH"
        ;;

    # Builds a self executable jar without bundle scala-library.jar. It assumes
    # that Scala is the $PATH variable, in other words that it is possible to
    # run $ scala command in the deployment machine.
    #
    # The advantage of this command is that it builds a more lightweight jar file.
    #
    -jar-to-sh2)
        INPUT_JAR=$2
        OUTPUT_SH="${INPUT_JAR%.*}.sh"        
        MAIN_CLASS=$(unzip -p $INPUT_JAR META-INF/MANIFEST.MF | grep Main-Class | cut -d : -f 2 |  tr -d $'\n' | tr -d $'\r')

        echo "Input      = "$INPUT_JAR
        echo "Output     = "$OUTPUT_SH
        echo "Main class = "$MAIN_CLASS
        
        cat <<EOF > $OUTPUT_SH
#!/usr/bin/env sh

# set -x

SCALA_LIB_PATH="\$(dirname \$(dirname \$(which scala)))"/lib

jars=""
for f in \$(ls \$SCALA_LIB_PATH); do
    jars=\$SCALA_LIB_PATH/\$f:\$jars
done
jars=\$jars"."

java -cp \$jars:\$0 $MAIN_CLASS

exit 0
EOF
        cat $INPUT_JAR >> $OUTPUT_SH
        #cat $OUTPUT_SH
        chmod +x $OUTPUT_SH

        echo "Build jar-executable $OUTPUT_SH"
        echo "Run it with ./$OUTPUT_SH"
        ;;



    # No working yet.
    -jar-download)
        mkdir -p lib
        cd lib
        groupId=$2
        artifactId=$3
        version=$4
        groupUri="${echo "${groupId}" | sed -e 's/\./\//g' }"
        jarFile=$artifactId-$version
        url="http://repo1.maven.org/maven2/$groupUri/$artifactId/$version/$jarFile"

        echo $url

        ;;

    # Show where are the scala libraries.
    -scala-lib)
        echo "Scala library path = "$SCALA_LIB_PATH
        echo ""
        echo "Scala run-time lib = "$SCALA_RUNTIME
        echo ""
        for f in $(ls $SCALA_LIB_PATH); do
            echo $SCALA_LIB_PATH/$f
        done
        ;;

    # Run a scala-jar compiled script using Scala run-time library
    -scala-run)
        java -cp $SCALA_RUNTIME:$2 Main "${@:3}"
        ;;

    -scala-repl)
          jars=""
          for f in $(ls ./lib); do
              jars=lib/$f:$jars
          done
          scala -cp $jars "${@:3}"
        ;;


    # Build a scala fat-jar
    -scala-build-jar)

        OUTPUT_JAR="$2"
        MAIN_JAR=$(realpath "$3")

        DEPS_JARS="${@:4}"

        OUTPUT_PATH=$(dirname $OUTPUT_JAR)

        # Create temporary directory to extract all jar files
        mkdir -p $OUTPUT_PATH/temp

        cd $OUTPUT_PATH/temp

        # Extract Scala runtime library
        jar -xf $SCALA_RUNTIME

        echo "At directory "$(pwd)

        for f in $DEPS_JARS; do

            if [ -f $f ]; then
                echo "Extracting "$jar
                jar -xf $f
            else
                jar=$(realpath "../../$f")
                if [ -f $jar ]; then
                    echo "Extracting "$jar
                    jar -xf $jar
                else
                    echo "Error file $jar not found"
                    exit 1
                fi
            fi
        done

        # Extract main jar
        jar -xf $MAIN_JAR


        echo -e "\nManifest Content META-INF/MANIFEST.MF\n"
        cat META-INF/MANIFEST.MF

        echo "Building fat-jar file ..."
        sleep 2
        jar -cmvf META-INF/MANIFEST.MF ../$(basename $OUTPUT_JAR) *


        ## Remove temporary files
        cd .. && rm -rf temp

        echo "--------------------------------------"
        echo -e "\nBuilt file: $OUTPUT_JAR Ok."
        echo -e "Run it with $ java -jar $OUTPUT_JAR"
    ;;

    *)
        cat <<EOF
Build fat jar. Tool like one-jar to build java fat jar.

Options:

 + Show information about Scala libraries.

    * ./$(basename $0) -scala-lib

 + Run an application compiled with Scala using its runtime.

   * ./$(basename $0) -scala-run scalaApp.jar

 + Start scala repl loading all *.jar files in classpath from ./lib

   * ./$(basename $0) -scala-repl

 + Build a fat jar for a Scala application. out/output-jar.jar. The
 main-jar file contains the main class.

   * ./$(basename $0) -scala-build-jar out/output-jar.jar main-jar.jar lib/dependency1.jar lib/dependency2.jar


 + Display manifest of a jar file.

   * ./$(basename $0) -jar-mainifest file.jar

 + Display main class of a jar file.

   * ./$(basename $0) -jar-main file.jar

 + View contents of a jar file

   * ./$(basename $0) -jar-view file.jar

 + Makes an executable, self-invocable jar-file from a fat-jar that
 can be run as ./jar-file.sh

   * ./$(basename $0) -jar-to-sh file.jar file.sh


Note: Use the command below to enable debug.

      $ env DEBUG=true ./build-fat-jar.sh

EOF


        exit 1

    ;;
esac
