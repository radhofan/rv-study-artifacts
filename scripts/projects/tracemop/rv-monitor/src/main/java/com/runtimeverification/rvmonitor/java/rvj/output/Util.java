package com.runtimeverification.rvmonitor.java.rvj.output;

import com.runtimeverification.rvmonitor.java.rvj.Main;
import com.runtimeverification.rvmonitor.java.rvj.parser.ast.PackageDeclaration;

public class Util {

    public static String getDefaultLocation() {
        if (Main.options.locationFromAjc) {
            return  "com.runtimeverification.rvmonitor.java.rt.ViolationRecorder.getLineOfCode("
                    + "joinpoint)";
        } else {
            return  "com.runtimeverification.rvmonitor.java.rt.ViolationRecorder.getLineOfCode()";
        }
    }

    public static String packageAndNameToUrl(
            PackageDeclaration packageDeclaration, String name) {
        return "http://runtimeverification.com/monitor/annotated-java/__properties/html/"
                + packageToUrlFragment(packageDeclaration)
                + "/"
                + name
                + ".html";
    }

    public static String packageToUrlFragment(
            PackageDeclaration packageDeclaration) {
        if (packageDeclaration == null)
            return "";
        return packageDeclaration.toString().replaceAll("[.]", "/")
                .replaceAll("(package\\s*)|;|\\s*", "");
    }
}
