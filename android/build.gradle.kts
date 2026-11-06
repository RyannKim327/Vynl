import com.android.build.api.dsl.LibraryExtension
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    afterEvaluate {
        val androidExtension = extensions.findByName("android")
        if (androidExtension is LibraryExtension) {
            if (androidExtension.namespace == null) {
                androidExtension.namespace = project.group.toString()
            }
            androidExtension.compileSdk = 36
            androidExtension.compileOptions.sourceCompatibility =
                JavaVersion.VERSION_17
            androidExtension.compileOptions.targetCompatibility =
                JavaVersion.VERSION_17
        }

        tasks.withType<KotlinCompile>().configureEach {
            compilerOptions.jvmTarget.set(JvmTarget.JVM_17)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
