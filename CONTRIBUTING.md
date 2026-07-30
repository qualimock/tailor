# Contributing to Tailor

Thanks for your interest in contributing! Here are the code style rules to keep the codebase clean and consistent.

## General Rules

* _Always_ use `var` for local variable declarations - let the compiler infer types. Only use explicit types when inference is ambiguous or impossible.

* _Always_ use `async`/`yield` for udisks2 calls, file I/O, and any other blocking operations. Never block the main thread.

* _Always_ wrap async calls in `try`/`catch` with typed errors. Do not silently swallow exceptions.

* Try _not_ to use `signal.connect()` for signals on widgets defined in a `[GtkTemplate]`. Wire all signals and bindings in the `.blp` file and resolve them in Vala via `[GtkCallback]`. Name mismatches are silent failures at runtime - be precise.

* _Never_ perform privileged drive operations via direct syscalls. All drive access goes through udisks2 D-Bus only.

* _Always_ show an Adwaita confirmation dialog before any destructive action.

## File Layout

A `.vala` source file for a `[GtkTemplate]` class must follow this member order:

1. Static fields (`private static ...`)
2. Instance fields (`private ...`)
3. `[GtkChild]` widget references
4. Properties (`public ... { get; set; }`). Backing fields (e.g. `_service`) are declared immediately before the property that uses them, not in the fields block
5. Signals (`public signal void ...`)
6. `static construct` - class-level type registration
7. `construct` - instance initializer shared across constructors
8. Constructor (`public ClassName (...)`)
9. Destructor
10. Public methods
11. Private methods
12. `[GtkCallback]` handlers

For non-template classes, omit the GTK-specific sections and follow the same rule.

## Logical Grouping

Within the private methods section, group by concern and keep groups together.
Do not interleave unrelated methods:

```
setup / init methods
event handlers (on_*)
helper predicates and formatters
pipeline steps (e.g. create → open → stream)
navigation helpers
```

Within `[GtkCallback]`, group by role:

```
expression helpers  (stringify, logical_and, greater_than, ...)
event handlers      (on_edition_selected, on_arch_selected, ...)
action / navigation (open_flash_page, ...)
```

Place helpers before or after their callers consistently within a file - do not mix both orderings.

## Blueprint and GtkCallback

Signals are wired in `.blp`:

```blp
Button {
  clicked => $on_flash_clicked();
}
```

And resolved in Vala:

```vala
[GtkCallback]
private void on_flash_clicked () {
    // handler body
}
```

Property bindings use closure expressions in `.blp`:

```blp
Label {
  label: bind $format_drive_size(drive.size) as <string>;
}
```

Resolved in Vala:

```vala
[GtkCallback]
private string format_drive_size (uint64 size) {
    return "%llu GB".printf (size / 1_000_000_000);
}
```

## Field vs Property

Use a plain field (`private Foo foo;`) when:

- The member is private with no external access
- No Blueprint binding references it
- No external class observes it via `notify`

Use a property (`public Foo foo { get; set; }`) when:

- It is bound in a `.blp` file via `bind template.foo`
- External classes observe it via `notify`
- It is a `[GtkChild]` reference (`[GtkChild] private unowned Widget foo;`)
