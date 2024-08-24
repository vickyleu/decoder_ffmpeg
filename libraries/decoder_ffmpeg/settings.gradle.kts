@file:Suppress("UnstableApiUsage")

rootProject.name = "decoder_ffmpeg"
enableFeaturePreview("TYPESAFE_PROJECT_ACCESSORS")

pluginManagement {
    repositories.apply {
        removeAll(this)
    }
    dependencyResolutionManagement.repositories.apply {
        removeAll(this)
    }
    listOf(repositories, dependencyResolutionManagement.repositories).forEach {
        it.apply {
            mavenCentral {
                content {
                    excludeGroupByRegex("com.android.tools.*")
                    excludeGroupByRegex("androidx.compose.*")
                }
            }
            gradlePluginPortal {
                content {
                    excludeGroupByRegex("androidx.databinding.*")
                }
            }
            google {
                content {
                    includeGroupByRegex(".*google.*")
                    includeGroupByRegex(".*android.*")
                    excludeGroupByRegex("com.github.*")
                }
            }
        }
    }

}

plugins {
    id("org.gradle.toolchains.foojay-resolver-convention") version "0.7.0"
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        mavenCentral {
            content {
                excludeGroupByRegex("com.finogeeks.*")
                excludeGroupByRegex("org.jogamp.*")
                excludeGroupByRegex("com.vickyleu.*")
                excludeGroupByRegex("org.jetbrains.compose.*")
                excludeGroupByRegex("com.github.(?!johnrengelman|oshi|bumptech|mzule|pwittchen|filippudak|asyl|florent37).*")
            }
        }
        google {
            content {
                excludeGroupByRegex("com.finogeeks.*")
                excludeGroupByRegex("media.kamel.*")
                excludeGroupByRegex("org.jogamp.*")
                includeGroupByRegex(".*google.*")
                includeGroupByRegex(".*android.*")
                excludeGroupByRegex("org.jetbrains.compose.*")
                excludeGroupByRegex("com.vickyleu.*")
                excludeGroupByRegex("com.github.(?!johnrengelman|oshi|bumptech).*")
            }
        }
    }
}

include(":")
