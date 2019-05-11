tterminalRQuote <- function (x) {
    paste0('"', gsub('"', '\\\\"', x), '"')
}


tterminalWrapResponse <- function (lines, callback = "Tapi_TterminalEvalCb") {
    vals <- as.character(force(lines))
    sprintf("[%s, %s, [%s]]",
        tterminalRQuote("call"),
        tterminalRQuote(callback),
        paste(tterminalRQuote(vals), collapse = ", "))
}


tterminalWrapOutput <- function (beg_marker, end_marker, ...) {
    cat("\n", beg_marker, "\n", tterminalWrapResponse(...), "\n", end_marker, "\n", sep = "")
    flush.console()
}


tterminalSendResponse <- function (...) {
    cat(paste0("\x1b]51;", tterminalWrapResponse(...), "\x07"))
    invisible(lines)
}


tterminalSendFileResponse <- function (tmpfile, lines) {
    vals <- as.character(force(lines))
    val <- paste0("[", paste(tterminalRQuote(vals), collapse = ", "), "]")
    cat(val, file = tmpfile, sep = "\n")
}


tterminalComplete <- function (base) {
    apropos(paste0("^", base), ignore.case = FALSE)
}


tterminalHelp <- function(name.string, ...) {
    help(name.string, try.all.packages = TRUE, ...)
}


tterminalKeyword <- function(name, name.string, ...) {
    if (name.string == '') {
        tterminalHelp(as.character(substitute(name)), ...)
    } else if (mode(name) == 'function') {
        tterminalHelp(name.string, ...)
    } else {
        str(name)
    }
}


### Credits:
### Based on https://github.com/jalvesaq/nvimcom/blob/master/R/etags2ctags.R
### Jakson Alves de Aquino
### Sat, July 17, 2010
### Licence: GPL2+
tterminalCtags <- function (ctagsfile = "tags") {
    wd <- gsub("\\", "/", getwd(), fixed = TRUE)
    home <- gsub("\\", "/", Sys.getenv("HOME"), fixed = TRUE)
    uprofile <- gsub("\\", "/", Sys.getenv("USERPROFILE"), fixed = TRUE)
    if (wd == home || wd == uprofile) {
        return()
    }
    rfile <- textConnection("rtags_lines", "w")
    rtags(recursive = TRUE, ofile = rfile, append = TRUE)
    on.exit({close(rfile); rm("rtags_lines", envir = .GlobalEnv)})
    ## etags2ctags(elines = rtags_lines, ctagsfile = 'tags')
    elines <- strsplit(rtags_lines, "\n", fixed = TRUE)
    filelen <- length(elines)
    nfread <- sum(elines == "\x0c")
    nnames <- filelen - (2 * nfread)
    clines <- vector(mode = "character", length = nnames)
    i <- 1
    k <- 1
    while (i < filelen) {
        if(elines[i] == "\x0c"){
            i <- i + 1
            curfile <- sub(",.*", "", elines[i])
            i <- i + 1
            curflines <- readLines(curfile)
            while(elines[i] != "\x0c" && i <= filelen){
                curname <- sub(".\x7f(.*)\x01.*", "\\1", elines[i])
                curlnum <- as.numeric(sub(".*\x01(.*),.*", "\\1", elines[i]))
                curaddr <- curflines[as.numeric(curlnum)]
                curaddr <- gsub("\\\\", "\\\\\\\\", curaddr)
                curaddr <- gsub("\t", "\\\\t", curaddr)
                curaddr <- gsub("/", "\\\\/", curaddr)
                curaddr <- paste("/^", curaddr, "$", sep = "")
                clines[k] <- paste(curname, curfile, curaddr, sep = "\t")
                i <- i + 1
                k <- k + 1
            }
        } else {
            stop("Error while trying to interpret line ", i, " of '", etagsfile, "'.\n")
        }
    }
    curcollate <- Sys.getlocale(category = "LC_COLLATE")
    invisible(Sys.setlocale(category = "LC_COLLATE", locale = "C"))
    clines <- sort(clines)
    invisible(Sys.setlocale(category = "LC_COLLATE", locale = curcollate))
    writeLines(clines, ctagsfile)
}


