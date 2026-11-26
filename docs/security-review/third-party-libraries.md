# Mass Records Approval – Third-Party Libraries

| Library   | Version | License | Where                                                                       | What is included | How it is used                                                                                                                               |
| --------- | ------- | ------- | --------------------------------------------------------------------------- | ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| Bootstrap | 5.0.2   | MIT     | Static resource `Bootstrap5` (`bootstrap-5.0.2-dist/css/bootstrap.min.css`) | CSS only         | Loaded with `loadStyle` through the package's own `global.css` by `massApprovalComponent` and `setupInstructionComponent` for layout styling |

- **No Bootstrap JavaScript** is included or loaded. The static resource contains only `css/bootstrap.min.css` and the
  package's own `global.css`.
- **No other third-party libraries** (JavaScript or CSS) are included. All other UI uses standard Lightning base components.
- **No external CDNs** are referenced; everything is served from the package's static resources.
