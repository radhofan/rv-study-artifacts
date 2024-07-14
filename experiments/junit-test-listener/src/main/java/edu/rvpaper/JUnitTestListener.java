package edu.rvpaper;

import org.junit.runner.notification.RunListener;
import org.junit.runner.Description;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;

public class JUnitTestListener extends RunListener {
    public void testStarted(Description description) {
        try {
            String test = description.getClassName() + "#" + description.getMethodName() + "\n";
            Files.write(Paths.get("tests.txt"), test.getBytes(), StandardOpenOption.APPEND,
                    StandardOpenOption.CREATE);
        } catch (IOException e) {
            System.out.println("JUnitTestListener cannot generate tests.txt");
        }
    }
}
