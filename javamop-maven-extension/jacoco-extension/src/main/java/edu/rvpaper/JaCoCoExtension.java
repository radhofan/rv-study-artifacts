package edu.rvpaper;

import org.apache.maven.eventspy.AbstractEventSpy;
import org.apache.maven.execution.ExecutionEvent;
import org.apache.maven.model.Plugin;
import org.apache.maven.model.PluginExecution;
import org.apache.maven.project.MavenProject;
import javax.inject.Named;
import javax.inject.Singleton;
import java.util.ArrayList;
import java.util.List;

@Named
@Singleton
public class JaCoCoExtension extends AbstractEventSpy {
    private void addJaCoCoPlugin(MavenProject project) {
        Plugin plugin = new Plugin();
        plugin.setGroupId("org.jacoco");
        plugin.setArtifactId("jacoco-maven-plugin");
        plugin.setVersion("0.8.11");

        List<PluginExecution> executions = getPluginExecutions();
        plugin.setExecutions(executions);

        Plugin oldJaCoCo = null;
        for (Plugin p : project.getBuild().getPlugins()) {
            if (p.getGroupId().equals("org.jacoco") && p.getArtifactId().equals("jacoco-maven-plugin")) {
                oldJaCoCo = p;
            }
        }

        if (oldJaCoCo != null) {
            // Remove old JaCoCo plugin
            project.getBuild().removePlugin(oldJaCoCo);
        }

        // Add new JaCoCo plugin
        project.getBuild().addPlugin(plugin);
    }

    private static List<PluginExecution> getPluginExecutions() {
        List<PluginExecution> executions = new ArrayList<>();

        PluginExecution prepare_execution = new PluginExecution();
        prepare_execution.addGoal("prepare-agent");
        prepare_execution.setId("prepare");
        executions.add(prepare_execution);

        PluginExecution report_execution = new PluginExecution();
        report_execution.addGoal("report");
        report_execution.setId("report");
        report_execution.setPhase("test");
        executions.add(report_execution);

        return executions;
    }

    @Override
    public void onEvent(Object event) {
        if (System.getenv("RUN_JACOCO_EXTENSION") == null ||
                !System.getenv("RUN_JACOCO_EXTENSION").equals("1")) {
            return;
        }

        if (event instanceof ExecutionEvent) {
            ExecutionEvent e = (ExecutionEvent) event;
            if (e.getType() == ExecutionEvent.Type.SessionStarted) {
                List<MavenProject> sortedProjects = e.getSession().getProjectDependencyGraph().getSortedProjects();
                for (MavenProject project : sortedProjects) {
                    addJaCoCoPlugin(project);
                }
            }
        }
    }
}
