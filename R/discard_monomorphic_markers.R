# Discard monomorphic markers

#' @name discard_monomorphic_markers

#' @title Discard monomorphic markers

#' @description Discard monomorphic markers.
#' Used internally in \href{https://github.com/thierrygosselin/radiator}{radiator}
#' and might be of interest for users.

#' @param data A tidy data frame object in the global environment or
#' a tidy data frame in wide or long format in the working directory.
#' \emph{How to get a tidy data frame ?}
#' Look into \pkg{radiator} \code{\link{tidy_genomic_data}}.


#' @param verbose (optional, logical) \code{verbose = TRUE} to be chatty
#' during execution.
#' Default: \code{verbose = FALSE}.

#' @return A list with the filtered input file and the blacklist of markers removed.

#' @export
#' @rdname discard_monomorphic_markers
#' @importFrom dplyr select mutate group_by ungroup rename tally filter semi_join n_distinct
#' @importFrom stringi stri_replace_all_fixed stri_join
#' @importFrom tibble has_name

#' @author Thierry Gosselin \email{thierrygosselin@@icloud.com}

discard_monomorphic_markers <- function(data, verbose = FALSE) {

  # Checking for missing and/or default arguments ------------------------------
  if (missing(data)) stop("Input file missing")

  # Import data ---------------------------------------------------------------
  if (is.vector(data)) {
    input <- radiator::tidy_wide(data = data, import.metadata = TRUE)
  } else {
    input <- data
  }

  # check genotype column naming
  if (tibble::has_name(input, "GENOTYPE")) {
    colnames(input) <- stringi::stri_replace_all_fixed(
      str = colnames(input),
      pattern = "GENOTYPE",
      replacement = "GT",
      vectorize_all = FALSE)
  }

  # necessary steps to make sure we work with unique markers and not duplicated LOCUS
  if (tibble::has_name(input, "LOCUS") && !tibble::has_name(input, "MARKERS")) {
    input <- dplyr::rename(.data = input, MARKERS = LOCUS)
  }

  if (tibble::has_name(input, "CHROM")) {
  markers.df <- dplyr::distinct(.data = input, MARKERS, CHROM, LOCUS, POS)
  }
  if (verbose) message("Scanning for monomorphic markers...")
  if (verbose) message("    Number of markers before = ", dplyr::n_distinct(input$MARKERS))

  mono.markers <- dplyr::select(.data = input, MARKERS, GT) %>%
    dplyr::filter(GT != "000000") %>%
    dplyr::distinct(MARKERS, GT) %>%
    dplyr::mutate(
      A1 = stringi::stri_sub(GT, 1, 3),
      A2 = stringi::stri_sub(GT, 4,6)
    ) %>%
    dplyr::select(-GT) %>%
    tidyr::gather(data = ., key = ALLELES_GROUP, value = ALLELES, -MARKERS) %>%
    dplyr::distinct(MARKERS, ALLELES) %>%
    dplyr::count(x = ., MARKERS) %>%
    dplyr::filter(n == 1) %>%
    dplyr::distinct(MARKERS)

  # Remove the markers from the dataset
  if (verbose) message("    Number of monomorphic markers removed = ", nrow(mono.markers))

  if (length(mono.markers$MARKERS) > 0) {
    input <- dplyr::anti_join(input, mono.markers, by = "MARKERS")
    if (verbose) message("    Number of markers after = ", dplyr::n_distinct(input$MARKERS))
    if (tibble::has_name(input, "CHROM")) {
      mono.markers <- dplyr::left_join(mono.markers, markers.df, by = "MARKERS")
    }
  } else {
    mono.markers <- tibble::data_frame(MARKERS = character(0))
  }

  want <- c("MARKERS", "CHROM", "LOCUS", "POS")
  whitelist.polymorphic.markers <- dplyr::select(input, dplyr::one_of(want)) %>%
    dplyr::distinct(MARKERS, .keep_all = TRUE)
  res <- list(input = input,
              blacklist.monomorphic.markers = mono.markers,
              whitelist.polymorphic.markers = whitelist.polymorphic.markers
              )
  return(res)
} # end discard mono markers

