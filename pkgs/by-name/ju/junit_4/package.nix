{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  jdk,
  java-hamcrest,
  stripJavaArchivesHook,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "junit";
  version = "4.13.2";

  src = fetchFromGitHub {
    owner = "junit-team";
    repo = "junit4";
    rev = "r${finalAttrs.version}";
    hash = "sha256-A6ZbmsECwP/hYqmIoU3rDvEX3V9Dx3FtCgAxpv8n8+Q=";
  };

  nativeBuildInputs = [
    jdk
    stripJavaArchivesHook
  ];

  propagatedBuildInputs = [ java-hamcrest ];

  postPatch = ''
    # Generate Version.java from the template (Maven normally does this)
    # The committed Version.java has a stale "4.13.2-SNAPSHOT" string
    cp src/main/java/junit/runner/Version.java.template \
       src/main/java/junit/runner/Version.java
    substituteInPlace src/main/java/junit/runner/Version.java \
      --replace-fail '@version@' '${finalAttrs.version}'

    # @Factory was removed from hamcrest 2.0+; it was a no-op marker annotation
    for f in \
      src/main/java/org/junit/internal/matchers/ThrowableMessageMatcher.java \
      src/main/java/org/junit/internal/matchers/StacktracePrintingMatcher.java \
      src/main/java/org/junit/internal/matchers/ThrowableCauseMatcher.java; do
      substituteInPlace "$f" \
        --replace-fail $'import org.hamcrest.Factory;\n' "" \
        --replace-fail $'    @Factory\n    ' "    "
    done

    # hamcrest 2.0+ changed everyItem return type from Matcher<Iterable<T>> to
    # Matcher<Iterable<? extends T>>; cast through Object to satisfy old signature
    substituteInPlace src/main/java/org/junit/matchers/JUnitMatchers.java \
      --replace-fail 'return CoreMatchers.everyItem(elementMatcher);' \
        'return (Matcher<Iterable<T>>) (Object) CoreMatchers.everyItem(elementMatcher);'
  '';

  buildPhase = ''
    runHook preBuild

    mkdir -p build/classes

    find src/main/java -name "*.java" > sources.txt

    javac \
      --release 8 \
      -classpath "$(find ${java-hamcrest}/share/java -name '*.jar' | tr '\n' ':')" \
      -encoding ISO-8859-1 \
      -d build/classes \
      @sources.txt

    cp -r src/main/resources/. build/classes/ 2>/dev/null || true

    jar cf junit-${finalAttrs.version}.jar -C build/classes .

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm644 junit-${finalAttrs.version}.jar $out/share/java/junit-${finalAttrs.version}.jar
    ln -s $out/share/java/junit-${finalAttrs.version}.jar $out/share/java/junit.jar

    runHook postInstall
  '';

  meta = {
    description = "JUnit 4 testing framework for Java";
    homepage = "https://junit.org/junit4/";
    license = lib.licenses.epl10;
    maintainers = with lib.maintainers; [ airone01 ];
    platforms = lib.platforms.all;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
  };
})
