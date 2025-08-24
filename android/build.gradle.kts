plugins {
  id("com.google.gms.google-services") version "4.4.3" apply false
}

// Define common Java/Kotlin versions
ext {
    set("compileSdkVersion", 36)
    set("minSdkVersion", 24)
    set("targetSdkVersion", 36)
    set("javaCompatibilityVersion", JavaVersion.VERSION_17)
    set("kotlinJvmTarget", "17")
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
