package edu.rvpaper;

import org.junit.runner.Result;
import org.junit.runner.notification.RunListener;
import org.junit.runner.Description;

import java.util.HashMap;
import java.util.Map;
import java.util.List;
import java.util.ArrayList;

public class JUnitMeasureTimeListener extends RunListener {

    private long startingTime = 0;

    private List<String> tests;
    private Map<String, Long> testsStartingTime;
    private Map<String, Long> testsEndingTime;

    public void testRunStarted(Description description) {
        tests = new ArrayList<>();
        testsStartingTime = new HashMap<>();
        testsEndingTime = new HashMap<>();
        startingTime = System.currentTimeMillis();
    }

    public void testRunFinished(Result result) {
        long endingTime = System.currentTimeMillis();
        System.out.println("[TSM] JUnit Total Time: " + (endingTime - startingTime));
        for (String test : tests) {
            System.out.println("[TSM] JUnit Test Time " + test + ": " + (testsEndingTime.getOrDefault(test, 0L) - (testsStartingTime.getOrDefault(test, 0L))));
        }
    }

    public void testStarted(Description description) {
        String test = description.getClassName() + "#" + description.getMethodName();

        long startingTime = System.currentTimeMillis();
        testsStartingTime.put(test, startingTime);
        tests.add(test);
    }

    public void testFinished(Description description) {
        long endingTime = System.currentTimeMillis();

        String test = description.getClassName() + "#" + description.getMethodName();
        testsEndingTime.put(test, endingTime);
    }
}
