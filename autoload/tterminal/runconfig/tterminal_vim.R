if (!exists('tterminalRQuote')) {
    tterminalRQuote <- function (x) {
        paste0('"', gsub('"', '\\\\"', x), '"')
    }
}


if (!exists('tterminalSendResponse')) {
    tterminalSendResponse <- function (lines, callback = "Tapi_TterminalEvalCb") {
        args <- paste(lines, collapse = ", ")
        resp <- sprintf("[%s, %s, [%s]]",
            tterminalRQuote("call"),
            tterminalRQuote(callback),
            paste(tterminalRQuote(lines), collapse = ", "))
        # cat(paste0("\x1b]51;[\"call\", \"Tapi_TterminalEvalCb\", [", paste(tterminalRQuote(lines), collapse = ", "), "]]\x07"))
        cat(paste0("\x1b]51;", resp, "\x07"))
        invisible(lines)
    }
}


if (!exists("tterminalComplete")) {
    tterminalComplete <- function (base) {
        cs <- apropos(paste0("^", base), ignore.case = FALSE)
        tterminalSendResponse(cs)
    }
}


if (!exists("tterminalHelp")) {
    tterminalHelp <- function(name.string, ...) {
        help(name.string, try.all.packages = TRUE, ...)
    }
}


if (!exists("tterminalKeyword")) {
    tterminalKeyword <- function(name, name.string, ...) {
        if (name.string == '') {
            tterminalHelp(as.character(substitute(name)), ...)
        } else if (mode(name) == 'function') {
            tterminalHelp(name.string, ...)
        } else {
            str(name)
        }
    }
}


if (!exists("tterminalCtags")) {
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
}

