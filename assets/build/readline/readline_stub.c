#include <stdio.h>
#include <string.h>
char *rl_line_buffer = NULL;
char *rl_readline_name;
void *rl_attempted_completion_function;
void *rl_completion_entry_function;
int rl_completion_query_items;
char *readline(const char *prompt) {
	char buf[512], *ptr;
	if(prompt) printf("%s", prompt);
	fflush(stdout); ptr = buf;
	while((*ptr = getchar()) != '\n') ptr++;
	*ptr = '\0';
	return strdup(buf);
}
void add_history(const char *string) {}
int rl_reset_terminal(const char *terminal_name) {return 0;}
char **rl_completion_matches(const char *text, void *entry_func) {return NULL;}
void rl_redisplay(void) {}