package edu.rvpaper.extension;

import org.apache.maven.AbstractMavenLifecycleParticipant;
import org.apache.maven.MavenExecutionException;
import org.apache.maven.execution.MavenSession;
import org.apache.maven.model.Build;
import org.apache.maven.model.Plugin;
import org.apache.maven.project.MavenProject;
import org.codehaus.plexus.component.annotations.Component;

@Component( role = AbstractMavenLifecycleParticipant.class, hint = "emop")
public class EMOPExtension extends AbstractMavenLifecycleParticipant {

    @Override
    public void afterSessionStart(MavenSession session) throws MavenExecutionException {

    }

    @Override
    public void afterProjectsRead(MavenSession session) throws MavenExecutionException {
        System.out.println("Modifying surefire to add EMOP...");
        for (MavenProject project : session.getProjects()) {
            // Do not add emop if it already has
            for (Plugin plugin : project.getBuildPlugins()) {
                if (plugin.getArtifactId().equals("emop-maven-plugin")) {
                    return;
                }
            }
            // eMOP plugin from: https://github.com/SoftEngResearch/emop
            Build build = project.getBuild();
            Plugin emop = new Plugin();
            emop.setGroupId("edu.cornell");
            emop.setArtifactId("emop-maven-plugin");
            emop.setVersion("1.0-SNAPSHOT");
            build.addPlugin(emop);
        }
    }

}
