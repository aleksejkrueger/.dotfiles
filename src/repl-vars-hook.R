#!/usr/bin/env Rscript

local({
  vars_file_env <- "NVIM_TMUX_VARS_FILE"
  preview_rows <- 500L
  json_max_depth <- 6L
  json_max_items <- 200L
  json_text_limit <- 300L

  replace_file <- function(tmp_path, path) {
    if (file.rename(tmp_path, path)) {
      return(invisible(TRUE))
    }

    unlink(path)
    invisible(file.rename(tmp_path, path))
  }

  json_escape <- function(value) {
    text <- gsub("\\", "\\\\", value, fixed = TRUE)
    text <- gsub("\"", "\\\"", text, fixed = TRUE)
    text <- gsub("\n", "\\n", text, fixed = TRUE)
    paste0("\"", text, "\"")
  }

  write_message_payload <- function(vars_file, message) {
    dir.create(dirname(vars_file), recursive = TRUE, showWarnings = FALSE)
    tmp_path <- paste0(vars_file, ".tmp")
    payload <- paste0(
      "{\"updated_at\":\"\",\"message\":",
      json_escape(message),
      ",\"vars\":[]}"
    )

    writeLines(payload, tmp_path, useBytes = TRUE)
    replace_file(tmp_path, vars_file)
    invisible(NULL)
  }

  source_original_profile <- function() {
    profile <- Sys.getenv("NVIM_TMUX_R_PROFILE_USER", "")
    hook_file <- Sys.getenv("NVIM_TMUX_R_HOOK_FILE", "")

    if (!nzchar(profile)) {
      candidates <- c(file.path(getwd(), ".Rprofile"), file.path(Sys.getenv("HOME"), ".Rprofile"))
      existing_profiles <- candidates[file.exists(candidates)]
      if (length(existing_profiles) > 0L) {
        profile <- existing_profiles[1]
      }
    }

    if (!nzchar(profile) || !file.exists(profile)) {
      return(invisible(NULL))
    }

    if (
      nzchar(hook_file) &&
        file.exists(hook_file) &&
        normalizePath(profile, mustWork = FALSE) == normalizePath(hook_file, mustWork = FALSE)
    ) {
      return(invisible(NULL))
    }

    tryCatch(
      source(profile, local = .GlobalEnv),
      error = function(error) message("Could not source R profile: ", conditionMessage(error))
    )
    invisible(NULL)
  }

  source_original_profile()

  vars_file <- Sys.getenv(vars_file_env, "")
  if (!nzchar(vars_file)) {
    return(invisible(NULL))
  }

  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    write_message_payload(vars_file, "Install the R package jsonlite for the vars pane.")
    return(invisible(NULL))
  }

  initial_names <- ls(envir = .GlobalEnv, all.names = FALSE)

  safe_file_name <- function(name) {
    safe_name <- gsub("[^[:alnum:]_.-]", "_", name)
    if (nzchar(safe_name)) {
      return(safe_name)
    }
    "variable"
  }

  snapshot_dir <- function(vars_path, suffix) {
    stem <- tools::file_path_sans_ext(basename(vars_path))
    file.path(dirname(vars_path), paste0(stem, "-", suffix))
  }

  table_dir <- function(vars_path) {
    snapshot_dir(vars_path, "tables")
  }

  figure_dir <- function(vars_path) {
    snapshot_dir(vars_path, "figures")
  }

  json_dir <- function(vars_path) {
    snapshot_dir(vars_path, "json")
  }

  table_path <- function(vars_path, name) {
    file.path(table_dir(vars_path), paste0(safe_file_name(name), ".json"))
  }

  figure_path <- function(vars_path, name) {
    file.path(figure_dir(vars_path), paste0(safe_file_name(name), ".png"))
  }

  json_path <- function(vars_path, name) {
    file.path(json_dir(vars_path), paste0(safe_file_name(name), ".json"))
  }

  truncate_text <- function(text, limit) {
    if (nchar(text, type = "chars", allowNA = FALSE) > limit) {
      return(paste0(substr(text, 1L, limit - 1L), "."))
    }
    text
  }

  short_text <- function(value, limit = 120L) {
    text <- tryCatch(
      {
        if (is.null(value)) {
          "NULL"
        } else if (is.atomic(value) && length(value) <= 5L) {
          paste(as.character(value), collapse = ", ")
        } else {
          paste(
            utils::capture.output(utils::str(value, max.level = 1L, list.len = 4L, vec.len = 4L)),
            collapse = " "
          )
        }
      },
      error = function(error) paste0("<repr failed: ", class(error)[1], ">")
    )

    text <- gsub("[[:space:]]+", " ", text)
    truncate_text(text, limit)
  }

  short_cell <- function(value, limit = 100L) {
    if (is.null(value) || length(value) == 0L) {
      return("")
    }

    text <- tryCatch(as.character(value)[1], error = function(error) paste0("<str failed: ", class(error)[1], ">"))
    if (is.na(text)) {
      text <- "NA"
    }

    text <- gsub("[[:space:]]+", " ", text)
    truncate_text(text, limit)
  }

  type_text <- function(value) {
    class_names <- class(value)
    if (length(class_names) > 0L) {
      return(class_names[1])
    }
    typeof(value)
  }

  detail_text <- function(value) {
    dimensions <- dim(value)
    if (!is.null(dimensions)) {
      return(paste0("dim=", paste(dimensions, collapse = "x")))
    }
    paste0("len=", length(value))
  }

  table_records <- function(value) {
    if (is.data.frame(value)) {
      preview <- utils::head(value, preview_rows)
      columns <- names(preview)
      rows <- lapply(seq_len(nrow(preview)), function(row_index) {
        unname(vapply(preview[row_index, columns, drop = FALSE], short_cell, character(1)))
      })
      return(list(columns = columns, rows = rows))
    }

    if (is.matrix(value)) {
      preview <- utils::head(value, preview_rows)
      columns <- colnames(preview)
      if (is.null(columns)) {
        columns <- paste0("V", seq_len(ncol(preview)))
      }
      rows <- lapply(seq_len(nrow(preview)), function(row_index) {
        vapply(seq_len(ncol(preview)), function(column_index) short_cell(preview[row_index, column_index]), character(1))
      })
      return(list(columns = columns, rows = rows))
    }

    NULL
  }

  write_table_snapshot <- function(vars_path, name, value) {
    records <- table_records(value)
    if (is.null(records)) {
      return("")
    }

    path <- table_path(vars_path, name)
    tmp_path <- paste0(path, ".tmp")
    payload <- list(
      name = jsonlite::unbox(name),
      type = jsonlite::unbox(type_text(value)),
      shape = jsonlite::unbox(detail_text(value)),
      columns = records$columns,
      rows = records$rows
    )

    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    jsonlite::write_json(payload, tmp_path, auto_unbox = FALSE, null = "null", na = "null")
    replace_file(tmp_path, path)
    path
  }

  json_key <- function(value) {
    truncate_text(if (is.character(value)) value else short_text(value, 120L), 120L)
  }

  json_scalar <- function(value) {
    if (is.factor(value)) {
      return(as.character(value)[1])
    }
    value[1]
  }

  json_value <- function(value, depth = 0L) {
    if (is.null(value)) {
      return(NULL)
    }

    if (depth >= json_max_depth) {
      return(short_text(value, json_text_limit))
    }

    if (is.atomic(value)) {
      if (length(value) <= 1L) {
        return(json_scalar(value))
      }

      item_count <- min(length(value), json_max_items)
      result <- lapply(seq_len(item_count), function(index) json_scalar(value[index]))
      if (length(value) > json_max_items) {
        result[[length(result) + 1L]] <- paste(length(value) - json_max_items, "more items")
      }
      return(result)
    }

    if (is.list(value) && !is.data.frame(value)) {
      item_count <- min(length(value), json_max_items)
      if (item_count == 0L) {
        return(list())
      }

      keys <- names(value)
      if (is.null(keys)) {
        keys <- as.character(seq_along(value))
      }
      keys[!nzchar(keys)] <- as.character(which(!nzchar(keys)))

      result <- lapply(seq_len(item_count), function(index) json_value(value[[index]], depth + 1L))
      names(result) <- make.unique(vapply(keys[seq_len(item_count)], json_key, character(1)))

      if (length(value) > json_max_items) {
        result[["..."]] <- paste(length(value) - json_max_items, "more items")
      }
      return(result)
    }

    short_text(value, json_text_limit)
  }

  write_json_snapshot <- function(vars_path, name, value) {
    if (!is.list(value) || is.data.frame(value)) {
      return("")
    }

    path <- json_path(vars_path, name)
    tmp_path <- paste0(path, ".tmp")
    payload <- list(
      name = name,
      type = type_text(value),
      data = json_value(value)
    )

    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    jsonlite::write_json(payload, tmp_path, auto_unbox = TRUE, null = "null", na = "null")
    replace_file(tmp_path, path)
    path
  }

  figure_like <- function(value) {
    inherits(value, "ggplot") || inherits(value, "recordedplot") || inherits(value, "trellis")
  }

  write_figure_snapshot <- function(vars_path, name, value) {
    if (!figure_like(value)) {
      return("")
    }

    path <- figure_path(vars_path, name)
    tmp_path <- paste0(path, ".tmp.png")
    device_open <- FALSE

    tryCatch(
      {
        dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
        grDevices::png(tmp_path, width = 1200L, height = 800L, res = 144L)
        device_open <- TRUE

        if (inherits(value, "recordedplot")) {
          grDevices::replayPlot(value)
        } else {
          print(value)
        }

        grDevices::dev.off()
        device_open <- FALSE
        replace_file(tmp_path, path)
        path
      },
      error = function(error) {
        if (device_open) {
          try(grDevices::dev.off(), silent = TRUE)
        }
        unlink(tmp_path)
        ""
      }
    )
  }

  remove_stale_snapshots <- function(snapshot_path, current_paths, pattern) {
    if (!dir.exists(snapshot_path)) {
      return(invisible(NULL))
    }

    for (path in Sys.glob(file.path(snapshot_path, pattern))) {
      if (!(path %in% current_paths)) {
        unlink(path)
      }
    }

    invisible(NULL)
  }

  should_include_name <- function(name) {
    nzchar(name) && !(name %in% initial_names) && !startsWith(name, ".")
  }

  should_include_value <- function(value) {
    !is.function(value) && !is.environment(value)
  }

  variable_rows <- function(vars_path) {
    rows <- list()
    table_paths <- character()
    figure_paths <- character()
    json_paths <- character()

    for (name in sort(ls(envir = .GlobalEnv, all.names = FALSE))) {
      if (!should_include_name(name)) {
        next
      }

      value <- get(name, envir = .GlobalEnv, inherits = FALSE)
      if (!should_include_value(value)) {
        next
      }

      current_table_path <- tryCatch(write_table_snapshot(vars_path, name, value), error = function(error) "")
      if (nzchar(current_table_path)) {
        table_paths <- c(table_paths, current_table_path)
      }

      current_figure_path <- tryCatch(write_figure_snapshot(vars_path, name, value), error = function(error) "")
      if (nzchar(current_figure_path)) {
        figure_paths <- c(figure_paths, current_figure_path)
      }

      current_json_path <- tryCatch(write_json_snapshot(vars_path, name, value), error = function(error) "")
      if (nzchar(current_json_path)) {
        json_paths <- c(json_paths, current_json_path)
      }

      viewer_kind <- ""
      viewer_path <- ""
      if (nzchar(current_figure_path)) {
        viewer_kind <- "figure"
        viewer_path <- current_figure_path
      } else if (nzchar(current_table_path)) {
        viewer_kind <- "table"
        viewer_path <- current_table_path
      } else if (nzchar(current_json_path)) {
        viewer_kind <- "json"
        viewer_path <- current_json_path
      }

      rows[[length(rows) + 1L]] <- list(
        name = jsonlite::unbox(name),
        type = jsonlite::unbox(type_text(value)),
        detail = jsonlite::unbox(detail_text(value)),
        value = jsonlite::unbox(short_text(value)),
        viewer_kind = jsonlite::unbox(viewer_kind),
        viewer_path = jsonlite::unbox(viewer_path)
      )
    }

    remove_stale_snapshots(table_dir(vars_path), table_paths, "*.json")
    remove_stale_snapshots(figure_dir(vars_path), figure_paths, "*.png")
    remove_stale_snapshots(json_dir(vars_path), json_paths, "*.json")
    rows
  }

  write_vars_snapshot <- function() {
    payload <- list(
      updated_at = jsonlite::unbox(format(Sys.time(), "%H:%M:%S")),
      vars = variable_rows(vars_file)
    )
    tmp_path <- paste0(vars_file, ".tmp")

    dir.create(dirname(vars_file), recursive = TRUE, showWarnings = FALSE)
    jsonlite::write_json(payload, tmp_path, auto_unbox = FALSE, null = "null", na = "null")
    replace_file(tmp_path, vars_file)
    invisible(NULL)
  }

  existing_callback_id <- get0(".nvim_tmux_vars_callback_id", envir = .GlobalEnv, inherits = FALSE)
  if (!is.null(existing_callback_id)) {
    try(removeTaskCallback(existing_callback_id), silent = TRUE)
  }

  assign(".nvim_tmux_write_vars_snapshot", write_vars_snapshot, envir = .GlobalEnv)
  callback <- function(expr, value, ok, visible) {
    try(write_vars_snapshot(), silent = TRUE)
    TRUE
  }
  callback_id <- addTaskCallback(callback, name = "nvim_tmux_vars")
  assign(".nvim_tmux_vars_callback_id", callback_id, envir = .GlobalEnv)

  write_vars_snapshot()
})
