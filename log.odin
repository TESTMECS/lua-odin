package ouau
import "core:log"

PBUG :: true
LOG_LIMIT :: 20
COUNT := 0
LOGSF :: proc(l := context.logger, f: string, xtra: ..any) {
	if COUNT < LOG_LIMIT {
		if PBUG && len(xtra) > 0 {
			l := log.create_console_logger()
			log.infof(f, ..xtra)
			COUNT += 1
		}
		 else if PBUG {
			l := log.create_console_logger()
			log.info(f)
			COUNT += 1
		}
	}
}

