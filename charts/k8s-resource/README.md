# k8s-resource

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.0.0](https://img.shields.io/badge/AppVersion-0.0.0-informational?style=flat-square)

A Helm chart that templates out whatever k8s resource you want.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| apiVersion | string | `nil` | The API version of the Kubernetes resource you're creating. |
| kind | string | `nil` |  |
| metadata | object | `nil` | metadata Metadata for the Kubernetes resource. |
| spec | object | `nil` | The specification for the Kubernetes resource. |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
