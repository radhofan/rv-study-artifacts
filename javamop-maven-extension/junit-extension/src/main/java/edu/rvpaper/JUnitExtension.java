package edu.rvpaper;

import org.apache.maven.artifact.versioning.ComparableVersion;
import org.apache.maven.eventspy.AbstractEventSpy;
import org.apache.maven.execution.ExecutionEvent;
import org.apache.maven.model.ConfigurationContainer;
import org.apache.maven.model.Dependency;
import org.apache.maven.model.Plugin;
import org.apache.maven.model.PluginExecution;
import org.apache.maven.project.MavenProject;
import org.codehaus.plexus.util.xml.Xpp3Dom;
import javax.inject.Named;
import javax.inject.Singleton;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Named
@Singleton
public class JUnitExtension extends AbstractEventSpy {

    private static final String DEPENDENCY_GROUP_ID = "edu.rvpaper";
    private static final String DEPENDENCY_ARTIFACT_ID = "junit-test-listener";
    private static final String DEPENDENCY_VERSION = "1.0";
    private static final String DEPENDENCY_PROPERTY_VALUE = "edu.rvpaper.JUnitTestListener";

    private enum JUnit_Version {
        JUNIT_4,    // JUnit >= 4.12
        JUNIT_5
    }

    private void addDependency(MavenProject project) {
        List<Dependency> dependencies = project.getDependencies();
        Dependency dependency = new Dependency();
        dependency.setGroupId(DEPENDENCY_GROUP_ID);
        dependency.setArtifactId(DEPENDENCY_ARTIFACT_ID);
        dependency.setVersion(DEPENDENCY_VERSION);
        dependencies.add(dependency);
        project.setDependencies(dependencies);
    }

    private void addListenerToProperties(Xpp3Dom properties) {
        Xpp3Dom property = new Xpp3Dom("property");

        Xpp3Dom name = new Xpp3Dom("name");
        name.setValue("listener");

        Xpp3Dom value = new Xpp3Dom("value");
        value.setValue(DEPENDENCY_PROPERTY_VALUE);

        property.addChild(name);
        property.addChild(value);
        properties.addChild(property);
    }

    private void updateConfig(Xpp3Dom config) {
        Xpp3Dom properties = config.getChild("properties");
        if (properties != null) {
            boolean hasListener = false;
            for (Xpp3Dom property : properties.getChildren()) {
                Xpp3Dom value = property.getChild("value");
                if (value != null && value.getValue().equals(DEPENDENCY_PROPERTY_VALUE)) {
                    hasListener = true;
                }
            }

            if (!hasListener) {
                addListenerToProperties(properties);
            }
        } else {
            properties = new Xpp3Dom("properties");
            addListenerToProperties(properties);
            config.addChild(properties);
        }
    }

    private Set<JUnit_Version> addDependencyIfNecessary(MavenProject project) {
        boolean hasListener = false;
        Set<JUnit_Version> versions = new HashSet<>();

        for (Dependency dependency : project.getDependencies()) {
            if (dependency.getGroupId().equals(DEPENDENCY_GROUP_ID) &&
                    dependency.getArtifactId().equals(DEPENDENCY_ARTIFACT_ID)) {
                hasListener = true;
            } else if (dependency.getGroupId().equals("junit") &&
                    (dependency.getArtifactId().equals("junit") || dependency.getArtifactId().equals("junit-dep"))) {
                ComparableVersion junitVersion = new ComparableVersion(dependency.getVersion());
                ComparableVersion minimumVersion = new ComparableVersion("4.11");

                if (junitVersion.compareTo(minimumVersion) < 0) {
                    dependency.setVersion("4.11");
                }

                versions.add(JUnit_Version.JUNIT_4);
            } else if (dependency.getGroupId().equals("org.junit.jupiter") &&
                    dependency.getArtifactId().equals("junit-jupiter-engine"))  {
                versions.add(JUnit_Version.JUNIT_5);
            }
        }

        if (!hasListener && versions.contains(JUnit_Version.JUNIT_4)) {
            // Add listener to dependencies if the project is using JUnit 4
            addDependency(project);
        }
        return versions;
    }

    private void updateSurefireVersion(Plugin plugin) {
        if (!plugin.getGroupId().equals("org.apache.maven.plugins") ||
                !plugin.getArtifactId().equals("maven-surefire-plugin")) {
            // Not Surefire
            return;
        }


        // getVersion will return null for project romix/java-concurrent-hash-trie-map
        String pluginVersion = plugin.getVersion() == null ? "0" : plugin.getVersion();
        ComparableVersion surefireVersion = new ComparableVersion(pluginVersion);
        ComparableVersion reasonableVersion = new ComparableVersion("3.1.2");
        if (surefireVersion.compareTo(reasonableVersion) < 0) {
            // Surefire is outdated, update it to `reasonableVersion`
            plugin.setVersion("3.1.2");
        }
    }

    private void checkAndUpdateConfiguration(ConfigurationContainer container) {
        Xpp3Dom configNode = (Xpp3Dom) container.getConfiguration();
        if (configNode == null) {
            configNode = new Xpp3Dom("configuration");
            container.setConfiguration(configNode);
        }
        updateConfig(configNode);
    }

    private void updateSurefire(MavenProject project, Set<JUnit_Version> versions) {
        for (Plugin plugin : project.getBuildPlugins()) {
            if (plugin.getGroupId().equals("org.apache.maven.plugins") &&
                    plugin.getArtifactId().equals("maven-surefire-plugin")) {
                updateSurefireVersion(plugin);

                if (versions.contains(JUnit_Version.JUNIT_4)) {
                    // For JUnit 4, we need to modify Surefire configuration
                    checkAndUpdateConfiguration(plugin);
                    for (PluginExecution exe : plugin.getExecutions()) {
                        checkAndUpdateConfiguration(exe);
                    }
                }
            }
        }
    }

    @Override
    public void onEvent(Object event) {
        if (System.getenv("JUNIT_TEST_LISTENER") == null ||
                !System.getenv("JUNIT_TEST_LISTENER").equals("1")) {
            return;
        }

        if (event instanceof ExecutionEvent) {
            ExecutionEvent e = (ExecutionEvent) event;
            if (e.getType() == ExecutionEvent.Type.SessionStarted) {
                List<MavenProject> sortedProjects = e.getSession().getProjectDependencyGraph().getSortedProjects();
                for (MavenProject project : sortedProjects) {
                    Set<JUnit_Version> versions = addDependencyIfNecessary(project);
                    updateSurefire(project, versions);
                }
            }
        }
    }
}
