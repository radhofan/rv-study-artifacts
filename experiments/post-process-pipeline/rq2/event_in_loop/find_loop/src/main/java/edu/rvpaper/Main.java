package edu.rvpaper;

import com.github.javaparser.JavaParser;
import com.github.javaparser.ParseResult;
import com.github.javaparser.Range;
import com.github.javaparser.ast.CompilationUnit;
import com.github.javaparser.ast.stmt.ForEachStmt;
import com.github.javaparser.ast.stmt.ForStmt;
import com.github.javaparser.ast.stmt.WhileStmt;

import static com.github.javaparser.ParserConfiguration.LanguageLevel.*;

import java.io.File;
import java.io.IOException;
import java.util.*;

public class Main {

    public static void main(String[] args) throws Exception {
        if (args.length < 1) {
            System.out.println("Missing argument: filename");
            System.exit(1);
        }

        listLoop(args[0]);
    }

    public static void listLoop(String fileName) throws IOException {
        JavaParser parser = new JavaParser();
        parser.getParserConfiguration().setLanguageLevel(JAVA_8);

        ParseResult<CompilationUnit> result = parser.parse(new File(fileName));
        if (!result.isSuccessful()) {
            System.out.println(result.getProblems());
            System.exit(1);
        }

        Optional<CompilationUnit> res = result.getResult();
        if (!res.isPresent()) {
            System.exit(1);
        }

        CompilationUnit cu = res.get();
        cu.findAll(ForStmt.class).forEach(
                statement -> {
                    Optional<Range> range = statement.getRange();
                    range.ifPresent(value -> System.out.println(value.begin.line + "." + value.end.line));
                }
        );

        cu.findAll(WhileStmt.class).forEach(
                statement -> {
                    Optional<Range> range = statement.getRange();
                    range.ifPresent(value -> System.out.println(value.begin.line + "." + value.end.line));
                }
        );

        cu.findAll(ForEachStmt.class).forEach(
                statement -> {
                    Optional<Range> range = statement.getRange();
                    range.ifPresent(value -> System.out.println(value.begin.line + "." + value.end.line));
                }
        );
    }
}
