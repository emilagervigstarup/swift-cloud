public enum Docker {}

extension Docker {
    public enum Dockerfile {}
}

extension Docker.Dockerfile {
    public static func write(_ contents: String, to path: String) throws {
        try Files.createFile(atPath: path, contents: contents)
        try Files.createFile(atPath: "\(path).dockerignore", contents: "\n")
    }

    public static func filePath(_ name: String) -> String {
        "\(Context.cloudAssetsDirectory)/Dockerfile.\(tokenize(name))"
    }
}

extension Docker.Dockerfile {
    private static func formatCommandArguments(_ arguments: [String]) -> String {
        arguments
            .map { "\"\($0)\"" }
            .joined(separator: ", ")
    }
    
    public static func awsLambda(targetName: String, architecture: Architecture = .current) -> String {
        """
# syntax=docker/dockerfile:1.6

############################
# 1) BUILDER (Amazon Linux 2 + Swift)
############################
ARG TARGETPLATFORM=linux/arm64
FROM --platform=$TARGETPLATFORM swift:6.0-amazonlinux2 AS builder
WORKDIR /src

# Kopiér kun det nødvendige for hurtigere layer-cache
COPY Package.* ./
COPY Sources ./Sources
# (tilføj evt. Resources/ osv. hvis de indgår i build)

# Byg release-binær og strip (ERSTAT <TARGET_NAME> med dit Swift target, fx UserUpload)
RUN swift build -c release \
 && strip -S -x .build/release/\(targetName)

############################
# 2) RUNTIME (AWS Lambda custom runtime - AL2)
############################
ARG TARGETPLATFORM=linux/arm64
FROM --platform=$TARGETPLATFORM public.ecr.aws/lambda/provided:al2

# Binæren SKAL hedde bootstrap og ligge i /var/runtime
COPY --from=builder /src/.build/release/\(targetName) /var/runtime/bootstrap

# Kopiér Swift stdlib + relaterede libs
COPY --from=builder /usr/lib/swift/linux/ /opt/swift-libs/
COPY --from=builder /usr/lib64/           /opt/usr-lib64/

# Gør eksekverbar og fjern evt. CRLF
RUN chmod 755 /var/runtime/bootstrap && sed -i 's/\r$//' /var/runtime/bootstrap

# Loaderen skal kunne finde libs
ENV LD_LIBRARY_PATH="/var/runtime:/var/task:/opt/swift-libs:/opt/usr-lib64:/lib64:/usr/lib64:/lib:/usr/lib"

        # Copy directories if they exist
        COPY ./Content* /var/task/Content
        COPY ./Public* /var/task/Public
        COPY ./Resources* /var/task/Resources
        COPY ./Output* /var/task/Output

        CMD [ "bootstrap" ]
        """
    }

    public static func amazonLinux(
        targetName: String,
        architecture: Architecture = .current,
        port: Int
    ) -> String {
        amazonLinux(
            targetName: targetName,
            architecture: architecture,
            port: port,
            arguments: ["--hostname", "0.0.0.0", "--port", "\(port)"]
        )
    }

    public static func amazonLinux(
        targetName: String,
        architecture: Architecture = .current,
        port: Int,
        arguments: [String]
    ) -> String {
        let commandArguments = formatCommandArguments(arguments)

        return """
        FROM amazonlinux:2

        WORKDIR /app/

        COPY ./.build/\(architecture.swiftBuildLinuxDirectory)/release/\(targetName) .
        COPY ./.build/\(architecture.swiftBuildLinuxDirectory)/release/*.resources .

        # Copy directories if they exist
        COPY ./Content* /app/Content
        COPY ./Public* /app/Public
        COPY ./Resources* /app/Resources
        COPY ./Output* /app/Output

        ENV SWIFT_BACKTRACE=enable=yes,sanitize=yes,threads=all,images=all,interactive=no,swift-backtrace=./swift-backtrace-static

        EXPOSE \(port)

        ENTRYPOINT [ "./\(targetName)" ]
        CMD [\(commandArguments)]
        """
    }

    public static func ubuntu(
        targetName: String,
        architecture: Architecture = .current,
        port: Int
    ) -> String {
        ubuntu(
            targetName: targetName,
            architecture: architecture,
            port: port,
            arguments: ["--hostname", "0.0.0.0", "--port", "\(port)"]
        )
    }

    public static func ubuntu(
        targetName: String,
        architecture: Architecture = .current,
        port: Int,
        arguments: [String]
    ) -> String {
        let commandArguments = formatCommandArguments(arguments)

        return """
        FROM ubuntu:noble

        RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
            && apt-get -q update \
            && apt-get -q dist-upgrade -y \
            && apt-get -q install -y \
            libjemalloc2 \
            ca-certificates \
            tzdata \
            libcurl4

        WORKDIR /app/

        COPY ./.build/\(architecture.swiftBuildLinuxDirectory)/release/\(targetName) .
        COPY ./.build/\(architecture.swiftBuildLinuxDirectory)/release/*.resources .

        # Copy directories if they exist
        COPY ./Content* /app/Content
        COPY ./Public* /app/Public
        COPY ./Resources* /app/Resources
        COPY ./Output* /app/Output

        ENV SWIFT_BACKTRACE=enable=yes,sanitize=yes,threads=all,images=all,interactive=no,swift-backtrace=./swift-backtrace-static

        EXPOSE \(port)

        ENTRYPOINT [ "./\(targetName)" ]
        CMD [\(commandArguments)]
        """
    }
}
