#' @include ggproto.r
NULL

#' @section Facets:
#'
#' All `facet_*` functions returns a `Facet` object or an object of a
#' `Facet` subclass. This object describes how to assign data to different
#' panels, how to apply positional scales and how to lay out the panels, once
#' rendered.
#'
#' Extending facets can range from the simple modifications of current facets,
#' to very laborious rewrites with a lot of [gtable()] manipulation.
#' For some examples of both, please see the extension vignette.
#'
#' `Facet` subclasses, like other extendible ggproto classes, have a range
#' of methods that can be modified. Some of these are required for all new
#' subclasses, while other only need to be modified if need arises.
#'
#' The required methods are:
#'
#'   - `compute_layout`: Based on layer data compute a mapping between
#'   panels, axes, and potentially other parameters such as faceting variable
#'   level etc. This method must return a data.frame containing at least the
#'   columns `PANEL`, `SCALE_X`, and `SCALE_Y` each containing
#'   integer keys mapping a PANEL to which axes it should use. In addition the
#'   data.frame can contain whatever other information is necessary to assign
#'   observations to the correct panel as well as determining the position of
#'   the panel.
#'
#'   - `map_data`: This method is supplied the data for each layer in
#'   turn and is expected to supply a `PANEL` column mapping each row to a
#'   panel defined in the layout. Additionally this method can also add or
#'   subtract data points as needed e.g. in the case of adding margins to
#'   `facet_grid()`.
#'
#'   - `draw_panels`: This is where the panels are assembled into a
#'   `gtable` object. The method receives, among others, a list of grobs
#'   defining the content of each panel as generated by the Geoms and Coord
#'   objects. The responsibility of the method is to decorate the panels with
#'   axes and strips as needed, as well as position them relative to each other
#'   in a gtable. For some of the automatic functions to work correctly, each
#'   panel, axis, and strip grob name must be prefixed with "panel", "axis", and
#'   "strip" respectively.
#'
#' In addition to the methods described above, it is also possible to override
#' the default behaviour of one or more of the following methods:
#'
#'   - `setup_params`:
#'   - `init_scales`: Given a master scale for x and y, create panel
#'   specific scales for each panel defined in the layout. The default is to
#'   simply clone the master scale.
#'
#'   - `train_scales`: Based on layer data train each set of panel
#'   scales. The default is to train it on the data related to the panel.
#'
#'   - `finish_data`: Make last-minute modifications to layer data
#'   before it is rendered by the Geoms. The default is to not modify it.
#'
#'   - `draw_back`: Add a grob in between the background defined by the
#'   Coord object (usually the axis grid) and the layer stack. The default is to
#'   return an empty grob for each panel.
#'
#'   - `draw_front`: As above except the returned grob is placed
#'   between the layer stack and the foreground defined by the Coord object
#'   (usually empty). The default is, as above, to return an empty grob.
#'
#'   - `draw_labels`: Given the gtable returned by `draw_panels`,
#'   add axis titles to the gtable. The default is to add one title at each side
#'   depending on the position and existence of axes.
#'
#' All extension methods receive the content of the params field as the params
#' argument, so the constructor function will generally put all relevant
#' information into this field. The only exception is the `shrink`
#' parameter which is used to determine if scales are retrained after Stat
#' transformations has been applied.
#'
#' @rdname ggplot2-ggproto
#' @format NULL
#' @usage NULL
#' @export
Facet <- ggproto("Facet", NULL,
  shrink = FALSE,
  params = list(),

  compute_layout = function(data, params) {
    cli::cli_abort("Not implemented")
  },
  map_data = function(data, layout, params) {
    cli::cli_abort("Not implemented")
  },
  init_scales = function(layout, x_scale = NULL, y_scale = NULL, params) {
    scales <- list()
    if (!is.null(x_scale)) {
      scales$x <- lapply(seq_len(max(layout$SCALE_X)), function(i) x_scale$clone())
    }
    if (!is.null(y_scale)) {
      scales$y <- lapply(seq_len(max(layout$SCALE_Y)), function(i) y_scale$clone())
    }
    scales
  },
  train_scales = function(x_scales, y_scales, layout, data, params) {
    # loop over each layer, training x and y scales in turn
    for (layer_data in data) {
      match_id <- match(layer_data$PANEL, layout$PANEL)

      if (!is.null(x_scales)) {
        x_vars <- intersect(x_scales[[1]]$aesthetics, names(layer_data))
        SCALE_X <- layout$SCALE_X[match_id]

        scale_apply(layer_data, x_vars, "train", SCALE_X, x_scales)
      }

      if (!is.null(y_scales)) {
        y_vars <- intersect(y_scales[[1]]$aesthetics, names(layer_data))
        SCALE_Y <- layout$SCALE_Y[match_id]

        scale_apply(layer_data, y_vars, "train", SCALE_Y, y_scales)
      }
    }
  },
  draw_back = function(data, layout, x_scales, y_scales, theme, params) {
    rep(list(zeroGrob()), length(unique0(layout$PANEL)))
  },
  draw_front = function(data, layout, x_scales, y_scales, theme, params) {
    rep(list(zeroGrob()), length(unique0(layout$PANEL)))
  },
  draw_panels = function(panels, layout, x_scales, y_scales, ranges, coord, data, theme, params) {
    cli::cli_abort("Not implemented")
  },
  draw_labels = function(panels, layout, x_scales, y_scales, ranges, coord, data, theme, labels, params) {
    panel_dim <-  find_panel(panels)

    xlab_height_top <- grobHeight(labels$x[[1]])
    panels <- gtable_add_rows(panels, xlab_height_top, pos = 0)
    panels <- gtable_add_grob(panels, labels$x[[1]], name = "xlab-t",
      l = panel_dim$l, r = panel_dim$r, t = 1, clip = "off")

    xlab_height_bottom <- grobHeight(labels$x[[2]])
    panels <- gtable_add_rows(panels, xlab_height_bottom, pos = -1)
    panels <- gtable_add_grob(panels, labels$x[[2]], name = "xlab-b",
      l = panel_dim$l, r = panel_dim$r, t = -1, clip = "off")

    panel_dim <-  find_panel(panels)

    ylab_width_left <- grobWidth(labels$y[[1]])
    panels <- gtable_add_cols(panels, ylab_width_left, pos = 0)
    panels <- gtable_add_grob(panels, labels$y[[1]], name = "ylab-l",
      l = 1, b = panel_dim$b, t = panel_dim$t, clip = "off")

    ylab_width_right <- grobWidth(labels$y[[2]])
    panels <- gtable_add_cols(panels, ylab_width_right, pos = -1)
    panels <- gtable_add_grob(panels, labels$y[[2]], name = "ylab-r",
      l = -1, b = panel_dim$b, t = panel_dim$t, clip = "off")

    panels
  },
  setup_params = function(data, params) {
    params$.possible_columns <- unique0(unlist(lapply(data, names)))
    params
  },
  setup_data = function(data, params) {
    data
  },
  finish_data = function(data, layout, x_scales, y_scales, params) {
    data
  },
  vars = function() {
    character(0)
  }
)

# Helpers -----------------------------------------------------------------

#' Quote faceting variables
#'
#' @description
#' Just like [aes()], `vars()` is a [quoting function][rlang::quotation]
#' that takes inputs to be evaluated in the context of a dataset.
#' These inputs can be:
#'
#' * variable names
#' * complex expressions
#'
#' In both cases, the results (the vectors that the variable
#' represents or the results of the expressions) are used to form
#' faceting groups.
#'
#' @param ... Variables or expressions automatically quoted. These are
#'   evaluated in the context of the data to form faceting groups. Can
#'   be named (the names are passed to a [labeller][labellers]).
#'
#' @seealso [aes()], [facet_wrap()], [facet_grid()]
#' @export
#' @examples
#' p <- ggplot(mtcars, aes(wt, disp)) + geom_point()
#' p + facet_wrap(vars(vs, am))
#'
#' # vars() makes it easy to pass variables from wrapper functions:
#' wrap_by <- function(...) {
#'   facet_wrap(vars(...), labeller = label_both)
#' }
#' p + wrap_by(vs)
#' p + wrap_by(vs, am)
#'
#' # You can also supply expressions to vars(). In this case it's often a
#' # good idea to supply a name as well:
#' p + wrap_by(drat = cut_number(drat, 3))
#'
#' # Let's create another function for cutting and wrapping a
#' # variable. This time it will take a named argument instead of dots,
#' # so we'll have to use the "enquote and unquote" pattern:
#' wrap_cut <- function(var, n = 3) {
#'   # Let's enquote the named argument `var` to make it auto-quoting:
#'   var <- enquo(var)
#'
#'   # `as_label()` will create a nice default name:
#'   nm <- as_label(var)
#'
#'   # Now let's unquote everything at the right place. Note that we also
#'   # unquote `n` just in case the data frame has a column named
#'   # `n`. The latter would have precedence over our local variable
#'   # because the data is always masking the environment.
#'   wrap_by(!!nm := cut_number(!!var, !!n))
#' }
#'
#' # Thanks to tidy eval idioms we now have another useful wrapper:
#' p + wrap_cut(drat)
vars <- function(...) {
  quos(...)
}


#' Is this object a faceting specification?
#'
#' @param x object to test
#' @keywords internal
#' @export
is.facet <- function(x) inherits(x, "Facet")

# A "special" value, currently not used but could be used to determine
# if faceting is active
NO_PANEL <- -1L

unique_combs <- function(df) {
  if (length(df) == 0) return()

  unique_values <- lapply(df, ulevels)
  rev(expand.grid(rev(unique_values), stringsAsFactors = FALSE,
    KEEP.OUT.ATTRS = TRUE))
}

df.grid <- function(a, b) {
  if (is.null(a) || nrow(a) == 0) return(b)
  if (is.null(b) || nrow(b) == 0) return(a)

  indexes <- expand.grid(
    i_a = seq_len(nrow(a)),
    i_b = seq_len(nrow(b))
  )
  unrowname(vec_cbind(
    a[indexes$i_a, , drop = FALSE],
    b[indexes$i_b, , drop = FALSE]
  ))
}

# A facets spec is a list of facets. A grid facetting needs two facets
# while a wrap facetting flattens all dimensions and thus accepts any
# number of facets.
#
# A facets is a list of grouping variables. They are typically
# supplied as variable names but can be expressions.
#
# as_facets() is complex due to historical baggage but its main
# purpose is to create a facets spec from a formula: a + b ~ c + d
# creates a facets list with two components, each of which bundles two
# facetting variables.

as_facets_list <- function(x) {
  x <- validate_facets(x)
  if (is_quosures(x)) {
    x <- quos_auto_name(x)
    return(list(x))
  }

  # This needs to happen early because we might get a formula.
  # facet_grid() directly converted strings to a formula while
  # facet_wrap() called as.quoted(). Hence this is a little more
  # complicated for backward compatibility.
  if (is_string(x)) {
    x <- parse_expr(x)
  }

  # At this level formulas are coerced to lists of lists for backward
  # compatibility with facet_grid(). The LHS and RHS are treated as
  # distinct facet dimensions and `+` defines multiple facet variables
  # inside each dimension.
  if (is_formula(x)) {
    return(f_as_facets_list(x))
  }

  # For backward-compatibility with facet_wrap()
  if (!is_bare_list(x)) {
    x <- as_quoted(x)
  }

  # If we have a list there are two possibilities. We may already have
  # a proper facet spec structure. Otherwise we coerce each element
  # with as_quoted() for backward compatibility with facet_grid().
  if (is.list(x)) {
    x <- lapply(x, as_facets)
  }

  x
}

validate_facets <- function(x) {
  if (inherits(x, "uneval")) {
    cli::cli_abort("Please use {.fn vars} to supply facet variables")
  }
  if (inherits(x, "ggplot")) {
    cli::cli_abort(c(
      "Please use {.fn vars} to supply facet variables",
      "i" = "Did you use {.code %>%} or {.code |>} instead of {.code +}?"
    ))
  }
  x
}


# Flatten a list of quosures objects to a quosures object, and compact it
compact_facets <- function(x) {
  x <- flatten_if(x, is_list)
  null_or_missing <- vapply(x, function(x) quo_is_null(x) || quo_is_missing(x), logical(1))
  new_quosures(x[!null_or_missing])
}

# Compatibility with plyr::as.quoted()
as_quoted <- function(x) {
  if (is.character(x)) {
    if (length(x) > 1) {
      x <- paste(x, collapse = "; ")
    }
    return(parse_exprs(x))
  }
  if (is.null(x)) {
    return(list())
  }
  if (is_formula(x)) {
    return(simplify(x))
  }
  list(x)
}
# From plyr:::as.quoted.formula
simplify <- function(x) {
  if (length(x) == 2 && is_symbol(x[[1]], "~")) {
    return(simplify(x[[2]]))
  }
  if (length(x) < 3) {
    return(list(x))
  }
  op <- x[[1]]; a <- x[[2]]; b <- x[[3]]

  if (is_symbol(op, c("+", "*", "~"))) {
    c(simplify(a), simplify(b))
  } else if (is_symbol(op, "-")) {
    c(simplify(a), expr(-!!simplify(b)))
  } else {
    list(x)
  }
}

f_as_facets_list <- function(f) {
  lhs <- function(x) if (length(x) == 2) NULL else x[-3]
  rhs <- function(x) if (length(x) == 2) x else x[-2]

  rows <- f_as_facets(lhs(f))
  cols <- f_as_facets(rhs(f))

  list(rows, cols)
}

as_facets <- function(x) {
  if (is_facets(x)) {
    return(x)
  }

  if (is_formula(x)) {
    # Use different formula method because plyr's does not handle the
    # environment correctly.
    f_as_facets(x)
  } else {
    vars <- as_quoted(x)
    as_quosures(vars, globalenv(), named = TRUE)
  }
}
f_as_facets <- function(f) {
  if (is.null(f)) {
    return(as_quosures(list()))
  }

  env <- f_env(f) %||% globalenv()

  # as.quoted() handles `+` specifications
  vars <- as.quoted(f)

  # `.` in formulas is ignored
  vars <- discard_dots(vars)

  as_quosures(vars, env, named = TRUE)
}
discard_dots <- function(x) {
  x[!vapply(x, identical, logical(1), as.name("."))]
}

is_facets <- function(x) {
  if (!is.list(x)) {
    return(FALSE)
  }
  if (!length(x)) {
    return(FALSE)
  }
  all(vapply(x, is_quosure, logical(1)))
}


# When evaluating variables in a facet specification, we evaluate bare
# variables and expressions slightly differently. Bare variables should
# always succeed, even if the variable doesn't exist in the data frame:
# that makes it possible to repeat data across multiple factors. But
# when evaluating an expression, you want to see any errors. That does
# mean you can't have background data when faceting by an expression,
# but that seems like a reasonable tradeoff.
eval_facets <- function(facets, data, possible_columns = NULL) {
  vars <- compact(lapply(facets, eval_facet, data, possible_columns = possible_columns))
  data_frame0(!!!tibble::as_tibble(vars))
}
eval_facet <- function(facet, data, possible_columns = NULL) {
  # Treat the case when `facet` is a quosure of a symbol specifically
  # to issue a friendlier warning
  if (quo_is_symbol(facet)) {
    facet <- as.character(quo_get_expr(facet))

    if (facet %in% names(data)) {
      out <- data[[facet]]
    } else {
      out <- NULL
    }
    return(out)
  }

  # Key idea: use active bindings so that column names missing in this layer
  # but present in others raise a custom error
  env <- new_environment(data)
  missing_columns <- setdiff(possible_columns, names(data))
  undefined_error <- function(e) cli::cli_abort("", class = "ggplot2_missing_facet_var")
  bindings <- rep_named(missing_columns, list(undefined_error))
  env_bind_active(env, !!!bindings)

  # Create a data mask and install a data pronoun manually (see ?new_data_mask)
  mask <- new_data_mask(env)
  mask$.data <- as_data_pronoun(mask)

  tryCatch(
    eval_tidy(facet, mask),
    ggplot2_missing_facet_var = function(e) NULL
  )
}

layout_null <- function() {
  # PANEL needs to be a factor to be consistent with other facet types
  data_frame0(
    PANEL = factor(1),
    ROW = 1,
    COL = 1,
    SCALE_X = 1,
    SCALE_Y = 1
  )
}

check_layout <- function(x) {
  if (all(c("PANEL", "SCALE_X", "SCALE_Y") %in% names(x))) {
    return()
  }

  cli::cli_abort("Facet layout has a bad format. It must contain columns {.col PANEL}, {.col SCALE_X}, and {.col SCALE_Y}")
}


#' Get the maximal width/length of a list of grobs
#'
#' @param grobs A list of grobs
#' @param value_only Should the return value be a simple numeric vector giving
#' the maximum in cm
#'
#' @return The largest value. measured in cm as a unit object or a numeric
#' vector depending on `value_only`
#'
#' @keywords internal
#' @export
max_height <- function(grobs, value_only = FALSE) {
  height <- max(unlist(lapply(grobs, height_cm)))
  if (!value_only) height <- unit(height, "cm")
  height
}
#' @rdname max_height
#' @export
max_width <- function(grobs, value_only = FALSE) {
  width <- max(unlist(lapply(grobs, width_cm)))
  if (!value_only) width <- unit(width, "cm")
  width
}
#' Find panels in a gtable
#'
#' These functions help detect the placement of panels in a gtable, if they are
#' named with "panel" in the beginning. `find_panel()` returns the extend of
#' the panel area, while `panel_cols()` and `panel_rows()` returns the
#' columns and rows that contains panels respectively.
#'
#' @param table A gtable
#'
#' @return A data.frame with some or all of the columns t(op), r(ight),
#' b(ottom), and l(eft)
#'
#' @keywords internal
#' @export
find_panel <- function(table) {
  layout <- table$layout
  panels <- layout[grepl("^panel", layout$name), , drop = FALSE]

  data_frame0(
    t = min(.subset2(panels, "t")),
    r = max(.subset2(panels, "r")),
    b = max(.subset2(panels, "b")),
    l = min(.subset2(panels, "l")),
    .size = 1
  )
}
#' @rdname find_panel
#' @export
panel_cols = function(table) {
  panels <- table$layout[grepl("^panel", table$layout$name), , drop = FALSE]
  unique0(panels[, c('l', 'r')])
}
#' @rdname find_panel
#' @export
panel_rows <- function(table) {
  panels <- table$layout[grepl("^panel", table$layout$name), , drop = FALSE]
  unique0(panels[, c('t', 'b')])
}
#' Take input data and define a mapping between faceting variables and ROW,
#' COL and PANEL keys
#'
#' @param data A list of data.frames, the first being the plot data and the
#' subsequent individual layer data
#' @param env The environment the vars should be evaluated in
#' @param vars A list of quoted symbols matching columns in data
#' @param drop should missing combinations/levels be dropped
#'
#' @return A data.frame with columns for PANEL, ROW, COL, and faceting vars
#'
#' @keywords internal
#' @export
combine_vars <- function(data, env = emptyenv(), vars = NULL, drop = TRUE) {
  possible_columns <- unique0(unlist(lapply(data, names)))
  if (length(vars) == 0) return(data_frame0())

  # For each layer, compute the facet values
  values <- compact(lapply(data, eval_facets, facets = vars, possible_columns = possible_columns))

  # Form the base data.frame which contains all combinations of faceting
  # variables that appear in the data
  has_all <- unlist(lapply(values, length)) == length(vars)
  if (!any(has_all)) {
    missing <- lapply(values, function(x) setdiff(names(vars), names(x)))
    missing_vars <- paste0(
      c("Plot", paste0("Layer ", seq_len(length(data) - 1))),
      " is missing {.var ", missing[seq_along(data)], "}"
    )
    names(missing_vars) <- rep("x", length(data))

    cli::cli_abort(c(
      "At least one layer must contain all faceting variables: {.var {names(vars)}}",
      missing_vars
    ))
  }

  base <- unique0(vec_rbind(!!!values[has_all]))
  if (!drop) {
    base <- unique_combs(base)
  }

  # Systematically add on missing combinations
  for (value in values[!has_all]) {
    if (empty(value)) next;

    old <- base[setdiff(names(base), names(value))]
    new <- unique0(value[intersect(names(base), names(value))])
    if (drop) {
      new <- unique_combs(new)
    }
    base <- unique0(vec_rbind(base, df.grid(old, new)))
  }

  if (empty(base)) {
    cli::cli_abort("Faceting variables must have at least one value")
  }

  base
}
#' Render panel axes
#'
#' These helpers facilitates generating theme compliant axes when
#' building up the plot.
#'
#' @param x,y A list of ranges as available to the draw_panel method in
#' `Facet` subclasses.
#' @param coord A `Coord` object
#' @param theme A `theme` object
#' @param transpose Should the output be transposed?
#'
#' @return A list with the element "x" and "y" each containing axis
#' specifications for the ranges passed in. Each axis specification is a list
#' with a "top" and "bottom" element for x-axes and "left" and "right" element
#' for y-axis, holding the respective axis grobs. Depending on the content of x
#' and y some of the grobs might be zeroGrobs. If `transpose=TRUE` the
#' content of the x and y elements will be transposed so e.g. all left-axes are
#' collected in a left element as a list of grobs.
#'
#' @keywords internal
#' @export
#'
render_axes <- function(x = NULL, y = NULL, coord, theme, transpose = FALSE) {
  axes <- list()
  if (!is.null(x)) {
    axes$x <- lapply(x, coord$render_axis_h, theme)
  }
  if (!is.null(y)) {
    axes$y <- lapply(y, coord$render_axis_v, theme)
  }
  if (transpose) {
    axes <- list(
      x = list(
        top = lapply(axes$x, `[[`, "top"),
        bottom = lapply(axes$x, `[[`, "bottom")
      ),
      y = list(
        left = lapply(axes$y, `[[`, "left"),
        right = lapply(axes$y, `[[`, "right")
      )
    )
  }
  axes
}
#' Render panel strips
#'
#' All positions are rendered and it is up to the facet to decide which to use
#'
#' @param x,y A data.frame with a column for each variable and a row for each
#' combination to draw
#' @param labeller A labeller function
#' @param theme a `theme` object
#'
#' @return A list with an "x" and a "y" element, each containing a "top" and
#' "bottom" or "left" and "right" element respectively. These contains a list of
#' rendered strips as gtables.
#'
#' @keywords internal
#' @export
render_strips <- function(x = NULL, y = NULL, labeller, theme) {
  list(
    x = build_strip(x, labeller, theme, TRUE),
    y = build_strip(y, labeller, theme, FALSE)
  )
}
