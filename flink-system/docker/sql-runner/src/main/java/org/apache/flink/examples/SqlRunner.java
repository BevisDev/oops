/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.apache.flink.examples;

import org.apache.flink.configuration.Configuration;
import org.apache.flink.table.api.TableEnvironment;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** Executes Flink SQL scripts used by realtime sync jobs. */
public final class SqlRunner {

    private static final Logger LOG = LoggerFactory.getLogger(SqlRunner.class);

    private static final String STATEMENT_DELIMITER = ";";
    private static final String LINE_DELIMITER = "\n";
    private static final String COMMENT_PATTERN = "(--.*)|(((/\\*)+?[\\w\\W]+?(\\*/)+))";
    private static final Pattern SET_STATEMENT_PATTERN =
            Pattern.compile("SET\\s+'(\\S+)'\\s+=\\s+'(.*)';", Pattern.CASE_INSENSITIVE);

    private static final String BEGIN_CERTIFICATE = "-----BEGIN CERTIFICATE-----";
    private static final String END_CERTIFICATE = "-----END CERTIFICATE-----";
    private static final String ESCAPED_BEGIN_CERTIFICATE = "======BEGIN CERTIFICATE=====";
    private static final String ESCAPED_END_CERTIFICATE = "=====END CERTIFICATE=====";

    private SqlRunner() {}

    public static void main(String[] args) throws Exception {
        if (args.length != 1) {
            throw new IllegalArgumentException("Exactly one SQL script path argument is expected.");
        }

        String script = Files.readString(Path.of(args[0]), StandardCharsets.UTF_8);
        List<String> statements = parseStatements(script);
        TableEnvironment tableEnv = TableEnvironment.create(new Configuration());

        for (String statement : statements) {
            Matcher setMatcher = SET_STATEMENT_PATTERN.matcher(statement.trim());
            if (setMatcher.matches()) {
                tableEnv.getConfig()
                        .getConfiguration()
                        .setString(setMatcher.group(1), setMatcher.group(2));
            } else {
                LOG.info("Executing:\n{}", statement);
                tableEnv.executeSql(statement);
            }
        }
    }

    static List<String> parseStatements(String script) {
        String formatted =
                formatSqlFile(script)
                        .replace(BEGIN_CERTIFICATE, ESCAPED_BEGIN_CERTIFICATE)
                        .replace(END_CERTIFICATE, ESCAPED_END_CERTIFICATE)
                        .replaceAll(COMMENT_PATTERN, "")
                        .replace(ESCAPED_BEGIN_CERTIFICATE, BEGIN_CERTIFICATE)
                        .replace(ESCAPED_END_CERTIFICATE, END_CERTIFICATE);

        List<String> statements = new ArrayList<>();
        StringBuilder current = null;
        boolean statementSet = false;

        for (String line : formatted.split("\n")) {
            String trimmed = line.trim();
            if (trimmed.isBlank()) {
                continue;
            }
            if (current == null) {
                current = new StringBuilder();
            }
            if (trimmed.startsWith("EXECUTE STATEMENT SET")) {
                statementSet = true;
            }
            current.append(trimmed).append('\n');
            if (trimmed.endsWith(STATEMENT_DELIMITER)) {
                if (!statementSet || trimmed.equals("END;")) {
                    statements.add(current.toString());
                    current = null;
                    statementSet = false;
                }
            }
        }
        return statements;
    }

    static String formatSqlFile(String content) {
        String trimmed = content.trim();
        StringBuilder formatted = new StringBuilder(trimmed);
        if (!trimmed.endsWith(STATEMENT_DELIMITER)) {
            formatted.append(STATEMENT_DELIMITER);
        }
        formatted.append(LINE_DELIMITER);
        return formatted.toString();
    }
}
