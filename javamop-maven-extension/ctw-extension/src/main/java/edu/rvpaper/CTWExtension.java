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
import java.util.ArrayList;
import java.util.List;

@Named
@Singleton
public class CTWExtension extends AbstractEventSpy {
    private void updateSurefireConfig(Xpp3Dom config) {
        Xpp3Dom myAspectsNode = new Xpp3Dom("additionalClasspathElement");
        myAspectsNode.setValue(System.getenv("MY_ASPECTS_JAR"));

        Xpp3Dom aspectjrtNode = new Xpp3Dom("additionalClasspathElement");
        aspectjrtNode.setValue(System.getenv("ASPECTJRT_JAR"));

        Xpp3Dom rvMonitorRTNode = new Xpp3Dom("additionalClasspathElement");
        rvMonitorRTNode.setValue(System.getenv("RV_MONITOR_RT_JAR"));


        Xpp3Dom classpathElements = config.getChild("additionalClasspathElements");
        if (classpathElements == null) {
            classpathElements = new Xpp3Dom("additionalClasspathElements");
            config.addChild(classpathElements);
        }

        classpathElements.addChild(myAspectsNode);
        classpathElements.addChild(aspectjrtNode);
        classpathElements.addChild(rvMonitorRTNode);
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

    private void checkAndUpdateConfiguration(ConfigurationContainer container, boolean forSurefire) {
        Xpp3Dom configNode = (Xpp3Dom) container.getConfiguration();
        if (configNode == null) {
            configNode = new Xpp3Dom("configuration");
            container.setConfiguration(configNode);
        }
        if (forSurefire) {
            updateSurefireConfig(configNode);
        } else {
            updateAspectJConfig(configNode);
        }
    }

    private void updateSurefire(MavenProject project) {
        for (Plugin plugin : project.getBuildPlugins()) {
            System.out.println(plugin.getGroupId());
            System.out.println(plugin.getConfiguration());

            if (plugin.getGroupId().equals("org.apache.maven.plugins") &&
                    plugin.getArtifactId().equals("maven-surefire-plugin")) {
                // Update maven-surefire-plugin's version and config
                updateSurefireVersion(plugin);
                checkAndUpdateConfiguration(plugin, true);

                for (PluginExecution exe : plugin.getExecutions()) {
                    checkAndUpdateConfiguration(exe, true);
                }
            } else if (plugin.getGroupId().equals("org.codehaus.mojo") &&
                    plugin.getArtifactId().equals("aspectj-maven-plugin")) {
                // Update aspectj-maven-plugin's config

                checkAndUpdateConfiguration(plugin, false);

                for (PluginExecution exe : plugin.getExecutions()) {
                    checkAndUpdateConfiguration(exe, false);
                }
            }
        }
    }

    private void insertDependencyToAllPlugin(MavenProject project) {
        Dependency dependency = new Dependency();
        dependency.setGroupId("org.aspectj");
        dependency.setArtifactId("aspectjtools");
        dependency.setVersion("1.9.7");

        for (Plugin plugin : project.getBuildPlugins()) {
            boolean found = false;

            for (Dependency dep : plugin.getDependencies()) {
               if (dep.getArtifactId().equals("aspectjtools")) {
                   found = true;
               }
            }

            if (!found) {
                plugin.getDependencies().add(dependency);
            }
        }
    }

    private void addDependencies(MavenProject project) {
        /*
        Add this to dependencies node
            <dependencies>
                <dependency>
                  <groupId>org.aspectj</groupId>
                  <artifactId>aspectjrt</artifactId>
                  <version>1.9.7</version>
                </dependency>

                <dependency>
                  <groupId>javamop-aspect</groupId>
                  <artifactId>javamop-aspect</artifactId>
                  <version>1.0</version>
                </dependency>

                <dependency>
                  <groupId>rv-monitor-rt</groupId>
                  <artifactId>rv-monitor-rt</artifactId>
                  <version>1.0</version>
                </dependency>
            </dependencies>
         */
       List<Dependency> dependencies = project.getDependencies();

       Dependency aspectjRT = new Dependency();
       aspectjRT.setGroupId("org.aspectj");
       aspectjRT.setArtifactId("aspectjrt");
       aspectjRT.setVersion("1.9.7");

       Dependency javamopAspect = new Dependency();
       javamopAspect.setGroupId("javamop-aspect");
       javamopAspect.setArtifactId("javamop-aspect");
       javamopAspect.setVersion("1.0");

       Dependency rvMonitorRV = new Dependency();
       rvMonitorRV.setGroupId("rv-monitor-rt");
       rvMonitorRV.setArtifactId("rv-monitor-rt");
       rvMonitorRV.setVersion("1.0");

       dependencies.add(aspectjRT);
       dependencies.add(javamopAspect);
       dependencies.add(rvMonitorRV);
    }

    private void addAspectJPlugin(MavenProject project) {
        Plugin plugin = new Plugin();
        plugin.setGroupId("org.codehaus.mojo");
        plugin.setArtifactId("aspectj-maven-plugin");
        plugin.setVersion("1.8");
        /*
        Add this to executions node
            <executions>
                <execution>
                    <goals>
                        <goal>compile</goal>
                        <goal>test-compile</goal>
                    </goals>
                </execution>
            </executions>
         */
        List<PluginExecution> executions = getPluginExecutions();
        plugin.setExecutions(executions);

        /*
        Add this to dependencies node
        <dependencies>
            <dependency>
              <groupId>org.aspectj</groupId>
              <artifactId>aspectjtools</artifactId>
              <version>1.9.7</version>
            </dependency>
        </dependencies>
         */
        List<Dependency> dependencies = getDependencies();
        plugin.setDependencies(dependencies);

        project.getBuild().addPlugin(plugin);
    }

    private static List<Dependency> getDependencies() {
        List<Dependency> dependencies = new ArrayList<>();
        Dependency dependency = new Dependency();
        dependency.setGroupId("org.aspectj");
        dependency.setArtifactId("aspectjtools");
        dependency.setVersion("1.9.7");
        dependencies.add(dependency);
        return dependencies;
    }

    private static List<PluginExecution> getPluginExecutions() {
        List<PluginExecution> executions = new ArrayList<>();
        PluginExecution execution = new PluginExecution();
        execution.addGoal("compile");
        execution.addGoal("test-compile");
        executions.add(execution);
        return executions;
    }

    private void updateAspectJConfig(Xpp3Dom configuration) {
        /*
        Add this to configuration node
            <configuration>
                <complianceLevel>1.8</complianceLevel>
                <source>1.8</source>
                <target>1.8</target>
                <showWeaveInfo>true</showWeaveInfo>
                <verbose>true</verbose>
                <Xlint>ignore</Xlint>
                <encoding>UTF-8 </encoding>
                <aspectLibraries>
                    <aspectLibrary>
                      <groupId>javamop-aspect</groupId>
                      <artifactId>javamop-aspect</artifactId>
                    </aspectLibrary>
                </aspectLibraries>
            </configuration>
         */

        Xpp3Dom complianceLevel = new Xpp3Dom("complianceLevel");
        complianceLevel.setValue("1.8");
        configuration.addChild(complianceLevel);

        Xpp3Dom source = new Xpp3Dom("source");
        source.setValue("1.8");
        configuration.addChild(source);

        Xpp3Dom target = new Xpp3Dom("target");
        target.setValue("1.8");
        configuration.addChild(target);

        Xpp3Dom showWeaveInfo = new Xpp3Dom("showWeaveInfo");
        showWeaveInfo.setValue("true");
        configuration.addChild(showWeaveInfo);

        Xpp3Dom verbose = new Xpp3Dom("verbose");
        verbose.setValue("true");
        configuration.addChild(verbose);

        Xpp3Dom Xlint = new Xpp3Dom("Xlint");
        Xlint.setValue("ignore");
        configuration.addChild(Xlint);

        Xpp3Dom encoding = new Xpp3Dom("encoding");
        encoding.setValue("UTF-8");
        configuration.addChild(encoding);


        Xpp3Dom aspectLibraries = new Xpp3Dom("aspectLibraries");
        Xpp3Dom aspectLibrary = new Xpp3Dom("aspectLibrary");

        Xpp3Dom groupId = new Xpp3Dom("groupId");
        groupId.setValue("javamop-aspect");

        Xpp3Dom artifactId = new Xpp3Dom("artifactId");
        artifactId.setValue("javamop-aspect");

        aspectLibrary.addChild(groupId);
        aspectLibrary.addChild(artifactId);
        aspectLibraries.addChild(aspectLibrary);
        configuration.addChild(aspectLibraries);
    }

    @Override
    public void onEvent(Object event) {
        if (System.getenv("MY_ASPECTS_JAR") == null || System.getenv("ASPECTJRT_JAR") == null || System.getenv("RV_MONITOR_RT_JAR") == null) {
            return;
        }

        if (event instanceof ExecutionEvent) {
            ExecutionEvent e = (ExecutionEvent) event;
            if (e.getType() == ExecutionEvent.Type.SessionStarted) {
                List<MavenProject> sortedProjects = e.getSession().getProjectDependencyGraph().getSortedProjects();
                for (MavenProject project : sortedProjects) {
                    insertDependencyToAllPlugin(project);

                    if (System.getenv("ADD_DEPENDENCY_ONLY") != null) {
                        addDependencies(project);
                        continue;
                    }

                    addAspectJPlugin(project);
                    addDependencies(project);
                    updateSurefire(project);
                }
            }
        }
    }
}
