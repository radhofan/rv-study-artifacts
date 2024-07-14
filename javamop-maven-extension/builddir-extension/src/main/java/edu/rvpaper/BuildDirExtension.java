package edu.rvpaper;

import org.apache.maven.eventspy.AbstractEventSpy;
import org.apache.maven.execution.ExecutionEvent;
import org.apache.maven.project.MavenProject;
import javax.inject.Named;
import javax.inject.Singleton;
import java.util.List;

@Named
@Singleton
public class BuildDirExtension extends AbstractEventSpy {
    @Override
    public void onEvent(Object event) {
        if (event instanceof ExecutionEvent) {
            ExecutionEvent e = (ExecutionEvent) event;
            if (e.getType() == ExecutionEvent.Type.SessionStarted) {
                List<MavenProject> sortedProjects = e.getSession().getProjectDependencyGraph().getSortedProjects();
                if (System.getenv("PROJECT_BUILD_DIRECTORY") != null) {
                    for (MavenProject project : sortedProjects) {
                        project.getBuild().setDirectory(System.getenv("PROJECT_BUILD_DIRECTORY"));
                    }
                }
            }
        }
    }
}
