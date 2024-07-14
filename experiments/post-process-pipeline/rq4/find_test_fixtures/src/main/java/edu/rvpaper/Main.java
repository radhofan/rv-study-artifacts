package edu.rvpaper;

import com.github.javaparser.JavaParser;
import com.github.javaparser.ParseResult;
import com.github.javaparser.ast.CompilationUnit;
import com.github.javaparser.ast.body.ClassOrInterfaceDeclaration;
import com.github.javaparser.ast.body.MethodDeclaration;
import com.github.javaparser.ast.expr.AnnotationExpr;

import static com.github.javaparser.ParserConfiguration.LanguageLevel.*;

import java.io.File;
import java.io.IOException;
import java.util.*;

public class Main {

    public static void main(String[] args) throws IOException {
        if (args.length < 1) {
            System.out.println("Missing argument: filename");
            System.exit(1);
        }

        JavaParser parser = new JavaParser();
        parser.getParserConfiguration().setLanguageLevel(JAVA_8);

        ParseResult<CompilationUnit> result = parser.parse(new File(args[0]));
        if (!result.isSuccessful()) {
            System.out.println(result.getProblems());
            System.exit(1);
        }

        Optional<CompilationUnit> res = result.getResult();
        if (!res.isPresent()) {
            System.exit(1);
        }
        
        CompilationUnit cu = res.get();
        cu.findAll(ClassOrInterfaceDeclaration.class).forEach(klass -> {
            // Check test classes
            Optional<String> className = klass.getFullyQualifiedName();
            if (!className.isPresent())
                return;
            String classNameSimple = klass.getNameAsString();

            System.out.println("class: " + className.get());

            // Check test fixtures
            klass.findAll(MethodDeclaration.class).forEach(method -> {
                if (method.getParentNode().isPresent() && method.getParentNode().get() instanceof ClassOrInterfaceDeclaration) {
                    if (!((ClassOrInterfaceDeclaration) method.getParentNode().get()).getNameAsString().equals(classNameSimple)) {
                        // Don't check for subclass' methods
                        return;
                    }
                }

                for (AnnotationExpr an : method.getAnnotations()) {
                    String annotation = an.getNameAsString();
                    if (annotation.startsWith("Before") || annotation.startsWith("After")) {
                        System.out.println("fixture: " + className.get() + "." + method.getNameAsString());
                    } else if (annotation.contains("Test") || annotation.contains("Theory")) {
                        System.out.println("test: " + className.get() + "." + method.getNameAsString());
                    }
                }
            });

            // Check test methods (JUnit 3)
            if (!klass.getExtendedTypes().isEmpty()) {
                // If the class extends another class, then we assume it doesn't require @Test
                klass.findAll(MethodDeclaration.class).forEach(method -> {
                    if (method.getParentNode().isPresent() && method.getParentNode().get() instanceof ClassOrInterfaceDeclaration) {
                        if (!((ClassOrInterfaceDeclaration) method.getParentNode().get()).getNameAsString().equals(classNameSimple)) {
                            // Don't check for subclass' methods
                            return;
                        }
                    }

                    if (method.getNameAsString().startsWith("test")) {
                        System.out.println("test: " + className.get() + "." + method.getNameAsString());
                    }
                });
            }
        });
    }
}
