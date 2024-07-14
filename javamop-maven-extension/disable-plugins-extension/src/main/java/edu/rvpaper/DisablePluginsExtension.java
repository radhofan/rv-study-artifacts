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
public class DisablePluginsExtension extends AbstractEventSpy {
    private void removePlugins(MavenProject project) {
        Plugin target = null;
        for (Plugin p : project.getBuild().getPlugins()) {
            if (p.getGroupId().equals("com.google.code.maven-replacer-plugin") && p.getArtifactId().equals("replacer")) {
                target = p;
            }
        }

        if (target != null) {
            // Remove plugin
            project.getBuild().removePlugin(target);
        }
    }

    @Override
    public void onEvent(Object event) {
        if (System.getenv("DISABLE_PLUGINS") == null ||
                !System.getenv("DISABLE_PLUGINS").equals("1")) {
            return;
        }

        if (event instanceof ExecutionEvent) {
            ExecutionEvent e = (ExecutionEvent) event;
            if (e.getType() == ExecutionEvent.Type.SessionStarted) {
                List<MavenProject> sortedProjects = e.getSession().getProjectDependencyGraph().getSortedProjects();
                for (MavenProject project : sortedProjects) {
                    removePlugins(project);
                }
            }
        }
    }
}
