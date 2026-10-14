allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Gradle 9 cannot snapshot OneDrive Files On-Demand reparse points. Keep build
// artifacts outside OneDrive on Windows while retaining the normal layout on
// every other machine.
val localAppData = System.getenv("LOCALAPPDATA")
val projectUsesOneDrive =
    rootProject.projectDir.absolutePath.contains("OneDrive", ignoreCase = true)
val buildDirectoryFile =
    if (projectUsesOneDrive && !localAppData.isNullOrBlank()) {
        file("$localAppData/MyGalleryBuild")
    } else {
        file("../build")
    }
rootProject.layout.buildDirectory.set(buildDirectoryFile)
val newBuildDir: Directory = rootProject.layout.buildDirectory.get()

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
