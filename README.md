# About this sample

This is a sample project for creating a typical web application using Service Fabric. The application consists of the following pieces:

1. An application gateway service. This is implemented as a stateless Service Fabric application that routes in-coming requests. It also hosts
a static HTML page. One can modify [GatewayService.cs](https://github.com/xinyanmsft/SFStartWebStateful/Application1.Gateway/GatewayService.cs) 
to customize the routing. This code is referenced from [Hosting Prototype](https://github.com/weidazhao/Hosting).

2. A web service created using WebAPI, running as a Service Fabric stateful service. Typically an application will have one or more such services, 
implementing various functionalities.

3. [Script](https://github.com/xinyanmsft/SFStartWebStateful/Setup_AppInsights.ps1) to setup Application Insight and generate the companion 
WAD configuration files.

4. [Script](https://github.com/xinyanmsft/SFStartWebStateful/Setup_CI_CD_VSO.ps1) to setup continuous integration and continuous deployment in 
Visual Studio Online.





