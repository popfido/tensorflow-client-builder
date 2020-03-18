# Introduction

[TensorFlow](https://github.com/tensorflow/tensorflow) is a popular Machine Learning toolkit, which includes [TF Serving](https://github.com/tensorflow/serving) which can serve the saved ML models via a Docker image that exposes [RESTful](https://github.com/tensorflow/serving/blob/master/tensorflow_serving/g3doc/api_rest.md) and [gRPC API](https://github.com/tensorflow/serving/tree/master/tensorflow_serving/apis).

Here is a [introduction of gRPC](https://grpc.io/docs/guides/index.html). The TF Serving's gRPC APIs are defined inside protobuf files and provide slightly more functionalities than the RESTful API. With these .proto files, you can generate the necessary client source code for various languages, and integrate the model serving function into your own application.

This repository is aiming at giving a step by step introduction on how to generate tensorflow server client code on different language platform (mainly for Java).

# Build your Tensorflow Java client

## Preparation

### Checkout this repository fron github

Before doing stuffs below to generate your tensorflow client, clone this repository from github to use it

```bash
$ git clone --recursive https://github.com/popfido/tensorflow-java-client.git
$ cd tensorflow-java-client
$ export SRC=$(pwd)
```

**Note**: the original tensorflow repository is quite large, thus time consuming of `--recursive` might be slower than your expectation due to network speed in different area. 

## Step 1. Get TensorFlow protobuf files

**Note**: Step 1 can be skipped since this repository has contained a version of tensorflow protobuf files with release 1.15.0.

### Check out the tensorflow projects somewhere

```bash
# Change 1.15.0 to any target release you wanna generate
$ export TARGET_RELEASE=1.15.0
$ cd $SRC/serving
$ git checkout tags/$TARGET_RELEASE

$ cd $SRC/tensorflow
$ git checkout tags/v$TARGET_RELEASE
```

### Gather all the .proto files and organize them into a new Java project.

The libraries we checked out contain many files, but we only need part of .proto files in order to compile our gRPC Java client. 
Thus let's make a project to host the source .proto files and future .java files.

```bash
$ export PROJECT_ROOT=$SRC/tensorflow-server-client
$ rm -rf $PROJECT_ROOT/src/main/proto
$ mkdir -p $PROJECT_ROOT/src/main/proto
```

Our end goal is to get all the .proto files required directly or indirectly by `tensorflow_serving/apis/*_service.proto` files. 
However, there are no tools that can start with a few .proto files and trace through the import statements and list all other .proto files required. 
So figuring out what files are needed is done by trying to compile the resulting Java classes till no 'no class def found' complaints. 
Alternatively one could simply include all .proto files from tensorflow_serving/ and tensorflow/, but it will result in much bigger Java package.

Let's try to pick out only .proto files and put `.proto` files into the new project's directories respectively under `src/main/proto` using the rsync commands, 
while still keep the directory structure, which is assumed by the import statements in these .proto files. 

```bash
$ rsync -arv  --prune-empty-dirs --include="*/" --include='*.proto' --exclude='*' $SRC/serving/tensorflow_serving  $PROJECT_ROOT/src/main/proto/
$ rsync -arv  --prune-empty-dirs --include="*/" --include="tensorflow/core/lib/core/*.proto" --include='tensorflow/core/framework/*.proto' --include="tensorflow/core/example/*.proto" --include="tensorflow/core/protobuf/*.proto" --include="tensorflow/stream_executor/*.proto" --exclude='*' $SRC/tensorflow/tensorflow  $PROJECT_ROOT/src/main/proto/
```

**Note**: The .proto files in these directories can change between releases, new files can be added, and file content can also change. So it is possible that the above 5 directories will contain .proto files that require other .proto files from directories outside. This repository is currently only tested under Tensorflow 1.15.0. So in case of that situation comes, you shall expand the .proto files to include those .proto files needed. But future test under other releases will be done.

## Step 2. Generate the Java files

Now we have a project with only .proto files under `src/main/proto/`. Let's compile them into Java source files.

### Build with maven

Build can be automated by using maven, the key dependencies declared in pom file are:

```xml
    <properties>
        <grpc.version>1.28.0</grpc.version>
        <protobuf.version>3.8.0</protobuf.version>
    </properties>
    
    <dependencies>
        <!-- gRPC protobuf client -->
        <dependency>
            <groupId>io.grpc</groupId>
            <artifactId>grpc-protobuf</artifactId>
            <version>${grpc.version}</version>
        </dependency>
        <dependency>
            <groupId>io.grpc</groupId>
            <artifactId>grpc-stub</artifactId>
            <version>${grpc.version}</version>
        </dependency>
        <dependency>
            <groupId>io.grpc</groupId>
            <artifactId>grpc-netty-shaded</artifactId>
            <version>${grpc.version}</version>
        </dependency>
    </dependencies>
```

Additionally, use the `protobuf-maven-plugin` which will compile .proto files to .java files. It will also generate extra `*Grpc.java` service stub files for each `*_service.proto` files:

```xml
    <build>
        <extensions>
            <extension>
                <groupId>kr.motd.maven</groupId>
                <artifactId>os-maven-plugin</artifactId>
                <version>1.6.2</version>
            </extension>
        </extensions>
        <plugins>
            <plugin>
                <groupId>org.xolstice.maven.plugins</groupId>
                <artifactId>protobuf-maven-plugin</artifactId>
                <version>0.6.1</version>
                <executions>
                    <execution>
                        <goals>
                            <goal>compile</goal>
                            <goal>compile-custom</goal>
                        </goals>
                    </execution>
                </executions>
                <configuration>
                    <checkStaleness>true</checkStaleness>
                    <protocArtifact>com.google.protobuf:protoc:${protobuf.version}:exe:${os.detected.classifier}</protocArtifact>
                    <pluginId>grpc-java</pluginId>
                    <pluginArtifact>io.grpc:protoc-gen-grpc-java:${grpc.version}:exe:${os.detected.classifier}</pluginArtifact>
                    <outputDirectory>${basedir}/src/main/java</outputDirectory>
                    <clearOutputDirectory>true</clearOutputDirectory>
                </configuration>
            </plugin>
        </plugins>
    </build>
```

Noted that the output directory has been set as `{project_base_dir}/src/main/java`. Thus after executing list of goals above, you shall find the compiled `.java` file inside `src/main/java`.

Here is the [documentation of this plugin](https://www.xolstice.org/protobuf-maven-plugin/), including the list of goals available. You can see it can compile the .proto files to **Java**, **C++**, **C#**, **Javascript**, or **Python**.

Notes:

- The `compile-custom` goal in the above pom will generate the `*Grpc.java` files, which are essential for the Java client, so keep it in your goal list.
- The plugin includes pre-compiled `protoc` executable for Linux, and is compiled using glibc, so it may not run correctly in Linux systems without glibc, e.g. alpine linux. So don't use a build server based on alpine Linux. See [more details](https://github.com/xolstice/protobuf-maven-plugin/issues/23#issuecomment-266098369).
- The `os-maven-plugin` extension is used to provide `${os.detected.classifier}`, in order to pull the correct executable for the build server/OS. [Eclipse IDE may require some special handling](https://github.com/trustin/os-maven-plugin#issues-with-eclipse-m2e-or-other-ides).

# Sample Java client code to make gRPC calls

```java
    String host = "localhost";
    int port = 8501;
    // the model's name. 
    String modelName = "cool_model";
    // model's version
    long modelVersion = 123456789;
    // assume this model takes input of free text, and make some sentiment prediction.
    String modelInput = "some text input to make prediction with";
    
    // create a channel
    ManagedChannel channel = ManagedChannelBuilder.forAddress(host, port).usePlaintext().build();
    PredictionServiceGrpc.PredictionServiceBlockingStub stub = PredictionServiceGrpc.newBlockingStub(channel);
    
    // create a modelspec
    Model.ModelSpec.Builder modelSpecBuilder = Model.ModelSpec.newBuilder();
    modelSpecBuilder.setName(modelName);
    modelSpecBuilder.setVersion(Int64Value.of(modelVersion));
    modelSpecBuilder.setSignatureName("serving_default");

    Predict.PredictRequest.Builder builder = Predict.PredictRequest.newBuilder();
    builder.setModelSpec(modelSpecBuilder);
    
    // create the TensorProto and request
    TensorProto.Builder tensorProtoBuilder = TensorProto.newBuilder();
    tensorProtoBuilder.setDtype(DataType.DT_STRING);
    TensorShapeProto.Builder tensorShapeBuilder = TensorShapeProto.newBuilder();
    tensorShapeBuilder.addDim(TensorShapeProto.Dim.newBuilder().setSize(1));
    tensorProtoBuilder.setTensorShape(tensorShapeBuilder.build());
    tensorProtoBuilder.addStringVal(ByteString.copyFromUtf8(modelInput));
    TensorProto tp = tensorProtoBuilder.build();

    builder.putInputs("inputs", tp);
    
    Predict.PredictRequest request = builder.build();
    Predict.PredictResponse response = stub.predict(request);
```

Additional engineering considerations:

- Creating a channel is an expensive operation, thus a connected channel should be cached.
- protobuf classes are dumb data holders, used for serialization and communication. You should build separate application specific object models that wraps around these protobuf classes, to provide additional behavior. Don't extend the protobuf classes for this purpose. See [Protobuf Java Tutorial](https://developers.google.com/protocol-buffers/docs/javatutorial).
