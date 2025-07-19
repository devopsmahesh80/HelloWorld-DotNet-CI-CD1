# Stage 1: Build the application
# Use the .NET SDK image to build the project
FROM [mcr.microsoft.com/dotnet/sdk:8.0](https://mcr.microsoft.com/dotnet/sdk:8.0) AS build
WORKDIR /app

# Copy solution and project files to restore dependencies
COPY *.sln .
COPY src/HelloWorld.Api/*.csproj ./src/HelloWorld.Api/
COPY tests/HelloWorld.Api.Tests/*.csproj ./tests/HelloWorld.Api.Tests/

# Restore dependencies for all projects
RUN dotnet restore

# Copy the rest of the source code
COPY . .

# Run tests as part of the build process
RUN dotnet test

# Publish the application, creating a release build
RUN dotnet publish src/HelloWorld.Api/HelloWorld.Api.csproj -c Release -o /app/out

# Stage 2: Create the final runtime image
# Use the smaller ASP.NET runtime image for efficiency
FROM [mcr.microsoft.com/dotnet/aspnet:8.0](https://mcr.microsoft.com/dotnet/aspnet:8.0) AS runtime
WORKDIR /app

# Copy the published output from the build stage
COPY --from=build /app/out .

# Expose the port the app will run on inside the container
EXPOSE 8080

# Define the entry point for the container
ENTRYPOINT ["dotnet", "HelloWorld.Api.dll"]