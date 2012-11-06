REM Create new user or use existing user "grant create session to js identified by js"
REM Pass username as parameter

undefine _usr

grant create type to                           &&_usr;
grant create procedure to                      &_usr;
grant execute on dbms_lock to                  &_usr;

grant select on gv_$sql to                     &_usr;
grant select on gv_$sql_monitor to             &_usr;
grant select on gv_$active_session_history to  &_usr;
grant select on gv_$osstat to                  &_usr;
grant select on gv_$instance to                &_usr;
grant select on gv_$statname to                &_usr;
grant select on gv_$sysstat to                 &_usr;
grant select on gv_$segment_statistics to      &_usr;
grant select on gv_$dlm_misc to                &_usr;
grant select on v_$parameter to                &_usr;

