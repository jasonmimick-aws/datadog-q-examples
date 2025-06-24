# Prompts used in Kiro to build this project

## Prompt 1

```
Hi - I would like to build a project which will contain a library of examples. 
These examples will show how to use Q cli and Datadog to solve real world problems.
For example, a customer is running a workload on AWS and errors occur which cause
application outages. Using the features of Q cli and Datadog customers can be
alerted to the issue, discusover the root cause, have Q cli and Datadog help
deisng and fix the issue, deploy a change, document the process and resolve
the incident. 

Can you generate a design doc and PRFAQ for such a project. 
The over all project should allow multiple developers to submit 
examples which are in a structured format and easy for customers 
to follow and resuse in their own environments.
```


## Prompt 2

```
Now let's build out out first example; First, let's generate the example
system - suppose we have a standard web application running wordpress
in ECS Fargate with a public endpoint and we use some AWS serverless Database. 
The application should also integrate Datadog for monitoring wheverpossible. 
All logs, metrics, and traces. Please use terraform to deploy the application.
Eventually we also want to be able to deploy Datadog dashboards to monitor the 
application via terraform, but for right now let's jsut build the this example. 
Let's call the example - "Serverless Wordpress on AWS with Datadog". 
Please follow the spec for this project.
```
