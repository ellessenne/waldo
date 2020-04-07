diff_split <- function(diff, n, size = 3) {
  diff$start <- pmax(diff$x1 - size, 1)
  diff$end <- pmin(diff$x2 + size, n)

  new_group <- c(TRUE, diff$start[-1] > diff$end[-nrow(diff)])
  group_id <- cumsum(new_group)
  split(diff, group_id)
}

diff_render <- function(diff, x, y, path, diff_a, diff_d, diff_c = NULL, diff_x = NULL, path_context, combine) {

  diff_c <- diff_c %||% function(x, y) c(diff_d(x), diff_a(y))
  diff_x <- diff_x %||% function(x) x

  n <- nrow(diff)
  start <- diff$start[[1]]
  end <- diff$end[[n]]

  out <- character()
  idx <- start
  for (i in seq_len(n)) {
    row <- diff[i, , drop = FALSE]
    if (idx < row$x1) {
      out <- c(out, diff_x(x[idx:(row$x1 - 1)]))
    }

    x_i <- row$x1:row$x2
    y_i <- row$y1:row$y2

    out <- c(out, switch(row$t,
      a = c(diff_x(x[x_i]), diff_a(y[y_i])),
      c = diff_c(x[x_i], y[y_i]),
      d = diff_d(x[x_i])
    ))
    idx <- row$x2 + 1
  }

  if (idx <= end) {
    out <- c(out, diff_x(x[idx:end]))
  }

  if (start != 1 || end != length(x)) {
    if (start != 1) {
      out <- c(diff_x("..."), out)
    }
    if (end != length(x)) {
      out <- c(out, diff_x("..."))
    }
    path <- path_context(path, start, end)
  }

  combine(paste0("`", path, "`"), out)
}

# values ------------------------------------------------------------------

diff_element <- function(x, y, path = ".", escape_string = TRUE) {
  if (is.character(x)) {
    x <- encodeString(x, quote = "'")
    y <- encodeString(y, quote = "'")
  }

  diff <- ses(x, y)
  if (nrow(diff) == 0) {
    return(new_compare())
  }

  chunks <- diff_split(diff, length(x))
  out <- map_chr(chunks, diff_render, x = x, y = y, path = path,
    diff_a = function(x) cli::col_blue("+", x),
    diff_d = function(x) cli::col_yellow("-", x),
    diff_c = function(x, y) paste0(cli::col_yellow(x), "/", cli::col_blue(y)),
    path_context = function(path, start, end) glue("{path}[{start}:{end}]"),
    combine = function(path, diff) paste0(path, ": ", paste0(diff, collapse = " "))
  )
  new_compare(out)
}

# lines -------------------------------------------------------------------

diff_lines <- function(x, y, path = ".") {
  x <- lines(x)
  y <- lines(y)

  diff <- ses(x, y)
  if (nrow(diff) == 0) {
    return(character())
  }

  chunks <- diff_split(diff, length(x))
  out <- map_chr(chunks, diff_render, x = x, y = y, path = path,
    diff_a = function(x) cli::col_blue("  + ", x),
    diff_d = function(x) cli::col_yellow("  - ", x),
    diff_c = function(x, y) diff_inline(x, y),
    diff_x = function(x) cli::col_grey("    ", x),
    path_context = function(path, start, end) glue("lines({path}, {start}:{end})"),
    combine = function(path, diff) paste0(path, ":\n", paste0(diff, collapse = "\n"))
  )
  new_compare(out)
}

lines <- function(x) {
  strsplit(x, "\r?\n")[[1]]
}

diff_inline <- function(x, y, path = ".") {
  x_cmp <- words(x)
  y_cmp <- words(y)

  diff <- ses(x_cmp, y_cmp)


  if (nrow(diff) == 0 || nrow(diff) / length(x_cmp) > 0.25) {
    return(c(cli::col_yellow("  - ", x), cli::col_blue("  + ", y)))
  }

  chunks <- diff_split(diff, length(x_cmp), size = 7)

  left <- map_chr(chunks, diff_render, x = x_cmp, y = y_cmp, path = path,
    diff_a = function(x) "",
    diff_d = function(x) cli::col_yellow("[-", paste0(encodeString(x), collapse = ""), "-]"),
    path_context = function(path, start, end) "",
    combine = function(path, diff) paste0(diff, collapse = "")
  )
  right <- map_chr(chunks, diff_render, x = x_cmp, y = y_cmp, path = path,
    diff_a = function(x) cli::col_blue("{+", paste0(encodeString(x), collapse = ""), "+}"),
    diff_d = function(x) "",
    path_context = function(path, start, end) "",
    combine = function(path, diff) paste0(diff, collapse = "")
  )

  c(paste0("  - ", left), paste0("  + ", right))
}

# words -------------------------------------------------------------------

diff_words <- function(x, y, path = ".") {
  if (x == y) {
    return(character())
  }

  x_cmp <- words(x)
  y_cmp <- words(y)

  diff <- ses(x_cmp, y_cmp)
  if (nrow(diff) == 0) {
    return(diff_element(x, y, path = path))
  }

  chunks <- diff_split(diff, length(x_cmp), size = 7)
  out <- map_chr(chunks, diff_render, x = x_cmp, y = y_cmp, path = path,
    diff_a = function(x) cli::col_blue("{+", paste0(encodeString(x), collapse = ""), "+}"),
    diff_d = function(x) cli::col_yellow("[-", paste0(encodeString(x), collapse = ""), "-]"),
    path_context = function(path, start, end) glue("words({path}, {start}:{end})"),
    combine = function(path, diff) paste0(path, ": ", paste0(diff, collapse = ""))
  )
  new_compare(out)
}

words <- function(x) {
  strsplit(x, "(?=\\s+)", perl = TRUE)[[1]]
}