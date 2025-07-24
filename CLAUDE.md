ADD or UPDATE logs in this component. When adding, check the relevent pom.xml for required dependencies.

- Info logs are used to communicate general information via the log file. These are printed during important actions of a server. There shouldn't be repetitive logs getting printed as error logs.  
- debug logs provide additional information needed to troubleshoot when a functionality doesn't work as expected. They should be disabled by default and should be enabled only when needed.
- WARN logs are to warn about something which is slightly deviated from the expected behaviour. Still, the server can function to deliver the expected results.
- Error logs help to identify the reason when a functionality doesn't work as expected.
- Following coding guidelines defined in https://github.com/wso2/code-quality-tools/blob/master/checkstyle/checkstyle.xml

Don't do the following,
- Don't do other code modificaitons. Just add or edit logs only.
- Don't add error logs when throwing the error as the error is logged when handling the error. 
- Don't make logs too long.
- Don't remove empty lines or do other code formatting.
- Don't do changes to any pom.xml files.
- Don't exceed the 120 characters for line limit.
- Don't add new files

Do the following,
- Make sure to limit the line length to 120 characters for checkstyle configuration.
- Add logs according to the imported log library in each file such as org.apache.commons.logging or org.apache.logging.log4j etc.
- Make logs context aware.
- Be aware about NPE when adding variables in logs.
- Re check the added code for the complience with WSO2 checkstyle rules : https://github.com/wso2/code-quality-tools/blob/master/checkstyle/checkstyle.xml