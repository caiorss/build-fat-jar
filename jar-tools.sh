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

    -jar-view)
        jar -tfv $2
        ;;

    # Convert jar to executable jar 
    -jar-to-sh)
        echo "Error: not implemented"
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
        java -cp $SCALA_RUNTIME:$2 Main
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

 + Build the fat jar out/output-jar.jar.
   The main-jar file contains the main class.

   * ./$(basename $0) -scala out/output-jar.jar main-jar.jar lib/dependency1.jar lib/dependency2.jar

Note: Use the command below to eanble debug.

      $ env DEBUG=true ./build-fat-jar.sh

EOF


        exit 1

    ;;
esac

