#ifndef READLINE_H
#define READLINE_H
typedef char *rl_compentry_func_t(const char*, int);
typedef char **rl_completion_func_t(const char*, int, int);
extern char *rl_line_buffer;
extern char *rl_readline_name;
extern rl_completion_func_t *rl_attempted_completion_function;
extern rl_compentry_func_t *rl_completion_entry_function;
extern int rl_completion_query_items;
char *readline(const char *prompt);
void add_history(const char *string);
int rl_reset_terminal(const char *terminal_name);
char **rl_completion_matches(const char *text, void *entry_func);
void rl_redisplay(void);
#endif