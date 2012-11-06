create or replace
package jss
as
FUNCTION gtop( pv_arr_size int default 47 , pv_sample  int default 6) RETURN ta_obj pipelined;
end;
/
show error


create or replace
PACKAGE body jss
AS
---##############
-- Global Variables
---##############
pv_first_ginst      ta_ginst := ta_ginst();   -- variables to store global instance info by using gv$sysstat, first sample
pv_last_ginst       ta_ginst := ta_ginst();   -- second sample, In order to get delta data

pv_only_gash        ta_gash  := ta_gash();    -- to store Gv$active_session_history data for given sample

pv_tmp_obj          ta_obj   := ta_obj() ;    -- temporary variable

pv_only_gsqlm        ta_gsqlm := ta_gsqlm();  -- to store gv$sql_monitor info, no delta

pv_num_cpus          int ;                    -- no. of cores from gv$iostat
pv_maxcpuprint       varchar2(100);           -- array no. to get maxcpu print in active session graph
p_sample             int;                     -- Input parameter for delay in sample/sleep time
pv_st_sample         date;                    -- sample start time from sysdate
pv_et_sample         date;                    -- sample end time from sysdate
pv_top_sql           ta_obj := ta_obj();      -- to store top sqls from pv_only_gash collection

pv_only_gc           ta_gc  :=  ta_gc();      -- Global Cache info from gv$sysstat
pv_block_size        number;                  -- Block size from v$parameter to calculate interconnect traffic

pv_tmp_gcinfo        ta_obj := ta_obj();      -- temporary global variable

----##################################################
-- Variables to draw active sessions Graph, 80 samples are shown in graph.
-- 4 arrays are used to show session range.
----##################################################
pa_stet  ta_obj := ta_obj();  pa1       ta_obj := ta_obj(); pa2       ta_obj := ta_obj();
pa3      ta_obj := ta_obj();  pa4       ta_obj := ta_obj(); pa5       ta_obj := ta_obj();
pa6      ta_obj := ta_obj();  pa7       ta_obj := ta_obj(); pa8       ta_obj := ta_obj();
pa9      ta_obj := ta_obj();  pa10      ta_obj := ta_obj(); pa11      ta_obj := ta_obj();
pa12     ta_obj := ta_obj();  pa13      ta_obj := ta_obj(); pa14      ta_obj := ta_obj();
pa15      ta_obj := ta_obj(); pa16      ta_obj := ta_obj(); pa17      ta_obj := ta_obj();
pa18      ta_obj := ta_obj(); pa19      ta_obj := ta_obj(); pa20      ta_obj := ta_obj();
pa21      ta_obj := ta_obj(); pa22      ta_obj := ta_obj(); pa23      ta_obj := ta_obj();
pa24      ta_obj := ta_obj(); pa25      ta_obj := ta_obj(); pa26      ta_obj := ta_obj();
pa27      ta_obj := ta_obj(); pa28      ta_obj := ta_obj(); pa29      ta_obj := ta_obj();
pa30      ta_obj := ta_obj(); pa31      ta_obj := ta_obj(); pa32      ta_obj := ta_obj();
pa33      ta_obj := ta_obj(); pa34      ta_obj := ta_obj(); pa35      ta_obj := ta_obj();
pa36      ta_obj := ta_obj(); pa37      ta_obj := ta_obj(); pa38      ta_obj := ta_obj();
pa39      ta_obj := ta_obj(); pa40      ta_obj := ta_obj(); pa41      ta_obj := ta_obj();
pa42      ta_obj := ta_obj(); pa43      ta_obj := ta_obj(); pa44      ta_obj := ta_obj();
pa45      ta_obj := ta_obj(); pa46      ta_obj := ta_obj(); pa47      ta_obj := ta_obj();
pa48      ta_obj := ta_obj(); pa49      ta_obj := ta_obj(); pa50      ta_obj := ta_obj();
pa51      ta_obj := ta_obj(); pa52      ta_obj := ta_obj(); pa53      ta_obj := ta_obj();
pa54      ta_obj := ta_obj(); pa55      ta_obj := ta_obj(); pa56      ta_obj := ta_obj();
pa57      ta_obj := ta_obj(); pa58      ta_obj := ta_obj(); pa59      ta_obj := ta_obj();
pa60      ta_obj := ta_obj(); pa61      ta_obj := ta_obj(); pa62      ta_obj := ta_obj();
pa63      ta_obj := ta_obj(); pa64      ta_obj := ta_obj(); pa65      ta_obj := ta_obj();
pa66      ta_obj := ta_obj(); pa67      ta_obj := ta_obj(); pa68      ta_obj := ta_obj();
pa69      ta_obj := ta_obj(); pa70      ta_obj := ta_obj(); pa71      ta_obj := ta_obj();
pa72      ta_obj := ta_obj(); pa73      ta_obj := ta_obj(); pa74      ta_obj := ta_obj();
pa75      ta_obj := ta_obj(); pa76      ta_obj := ta_obj(); pa77      ta_obj := ta_obj();
pa78      ta_obj := ta_obj(); pa79      ta_obj := ta_obj(); pa80      ta_obj := ta_obj();
pa81      ta_obj := ta_obj(); pa82      ta_obj := ta_obj(); pa83      ta_obj := ta_obj();
pa84      ta_obj := ta_obj();

pv_maxval    int ;    --- info regarding maxval of Active Session Graph array
pv_tmp_maxval int;    --- for reshuffling the maxval based on current active sessions
pv_maxsess   int ;    --- max sessions reached in last 80 samples

 ------------------ to store waits
pv_cpuwaitpct int;
pv_iowaitpct  int;
pv_cluwaitpct int;
pv_othwaitpct int;

pv_cpu_dig     varchar2(1) := '#';
pv_io_dig     varchar2(1) :=  'O';
pv_clu_dig    varchar2(1) :=  '+';
pv_oth_dig    varchar2(1) :=  '*';



p_localarray   int := 0;

pva int;
pvb int;
pvc int;
pvd int;
pve int;

js_maxsess  int := 0;
js_arr      int := 0 ;
pv_work_done  int := 0;


----##################################################/



------##################
--Initial Procedure to extend all the arrays to ASG [Active Sessions Graph ]
------##################
procedure initactarr
as
begin
 ---extending arrays
    pa1.extend(21);   pa2.extend(21);  pa3.extend(21);  pa4.extend(21);  pa5.extend(21);
    pa6.extend(21);   pa7.extend(21);  pa8.extend(21);  pa9.extend(21);  pa10.extend(21);
    pa11.extend(21);  pa12.extend(21); pa13.extend(21); pa14.extend(21); pa15.extend(21);
    pa16.extend(21); pa17.extend(21); pa18.extend(21); pa19.extend(21); pa20.extend(21);
    pa21.extend(21); pa22.extend(21); pa23.extend(21); pa24.extend(21); pa25.extend(21);
    pa26.extend(21); pa27.extend(21); pa28.extend(21); pa29.extend(21); pa30.extend(21);
    pa31.extend(21); pa32.extend(21); pa33.extend(21); pa34.extend(21); pa35.extend(21);
    pa36.extend(21); pa37.extend(21); pa38.extend(21); pa39.extend(21); pa40.extend(21);
    pa41.extend(21); pa42.extend(21); pa43.extend(21); pa44.extend(21); pa45.extend(21);
    pa46.extend(21); pa47.extend(21); pa48.extend(21); pa49.extend(21); pa50.extend(21);
    pa51.extend(21); pa52.extend(21); pa53.extend(21); pa54.extend(21); pa55.extend(21);
    pa56.extend(21); pa57.extend(21); pa58.extend(21); pa59.extend(21); pa60.extend(21);
    pa61.extend(21); pa62.extend(21); pa63.extend(21); pa64.extend(21); pa65.extend(21);
    pa66.extend(21); pa67.extend(21); pa68.extend(21); pa69.extend(21); pa70.extend(21);
    pa71.extend(21); pa72.extend(21); pa73.extend(21); pa74.extend(21); pa75.extend(21);
    pa76.extend(21); pa77.extend(21); pa78.extend(21); pa79.extend(21); pa80.extend(21);
exception
when others then
raise_application_Error(-20001,'INITACTARR : '||sqlerrm );
end;
-------------------/


------##################
-- ginsteff build data set from gv$sysstat, gv$osstat, gv$dlm_misc
-- and load data collection name pv_last_ginst
-- only every loop, pv_last_ginst will be assigned to pv_first_ginst to get the delta
------##################
function ginsteff return ta_ginst
is
fv_ginst  ta_ginst := ta_ginst();
fv_sql    varchar2(3000) := q'[Select  ty_ginst(a.instance_number,a.instance_name,b.name,c.value,sysdate)
                               from gv$instance a , gv$statname b, gv$sysstat c
                               where a.inst_id = b.inst_id and b.inst_id = c.inst_id and b.statistic# = c.statistic# and b.name in
                               ('execute count', 'parse count (hard)', 'parse count (total)',
                               'physical read total IO requests', 'physical read total bytes',
                               'physical write total IO requests', 'physical write total bytes',
                               'redo size', 'session logical reads', 'user commits',
                                'cell physical IO interconnect bytes returned by smart scan',
                                'cell physical IO bytes saved by storage index','cell flash cache read hits',
                                'gc cr blocks served','gc current blocks served','gc cr blocks received','gc current blocks received',
                                'gcs messages sent','ges messages sent'
                                )
                               union all
                               select  ty_ginst(d.inst_id,e.instance_name,d.stat_name,d.value,sysdate)
                               from gv$osstat d, gv$instance e
                               where d.inst_id = e.inst_id and d.stat_name in
                               ('IDLE_TIME','USER_TIME','SYS_TIME','IOWAIT_TIME','BUSY_TIME','NICE_TIME','NUM_CPU_CORES')
                               union all
                               select  ty_ginst(i.inst_id,i.instance_name,d.name,d.value,sysdate)
                               from gv$instance i, gv$dlm_misc d
                               where i.inst_id = d.inst_id and d.name in ('gcs msgs received', 'ges msgs received')
                                ]';

begin
execute immediate fv_sql bulk collect into fv_ginst;
return fv_ginst;
exception
when others then
raise_application_Error(-20001,'GINSTEFF : '||sqlerrm );
end;
-------------------/





------##################
-- ginstbuilddata - once data set is ready by calling ginsteff [ above function ], ginstbuilddata
-- format the data by query both samples [ pv_first_ginst and pv_last_ginst ]
------##################

function ginstbuilddata (fv_firstsample ta_ginst, fv_lastsample  ta_ginst) return ta_obj
is
fv_ta_obj      ta_obj := ta_obj();
v_sampl_time   int;
v_total_time   int;
-- Variables to store sum values for cluster
vt_tprse       int := 0;
vt_hprse       int := 0;
vt_phwio       int := 0;
vt_phwmb       int := 0;
vt_phrio       int := 0;
vt_phrmb       int := 0;
vt_slio        int := 0;
vt_exec        int := 0;
vt_redo        int := 0;
vt_comt        int := 0;
vt_exSS        int := 0;
vt_exSI        int := 0;
vt_exFC        int := 0;

begin
pv_only_gc.delete;

fv_ta_obj.extend;
fv_ta_obj(fv_ta_obj.count) := ty_obj( '+Inst-------+CPUIDL%--IO%-USR%--SYS%+--Tprse/s--+Hprse/s+--PhyWIO/s-+-PhyWMB/s-+--PhyRIO/s--+-PhyRMB/s-+-SessLIO/s--+---Exec/s-+RedoMB/s+Commit/s+-ExSSMB/s-+-ExSIMB/s+-ExFCRh/s+') ;


    --- updating CPU info -- updating with every sample in case new node join/leave the cluser
              select  sum(first.value) into pv_num_cpus from table (fv_firstsample) first where first.statname = 'NUM_CPU_CORES';
      --- Initializing package variables with sample time for later use.
              select    first.times,last.times  into pv_st_sample, pv_et_sample from table (fv_firstsample) first, table( fv_lastsample ) last where rownum = 1;
         -----# Not using pv_sample as selecting across multiple instances may take more time, so would be wise to calculate sample based on timestamps
                v_sampl_time :=   (pv_et_sample - pv_st_sample ) *24*60*60 ;

    -------
   for i in ( select distinct inst_id from table(fv_lastsample ) order by inst_id ) loop     -- processing order by inst_id. Pls. note : no restriction on no. of instances

            -------------
            for ii in (select b.inst_id,b.inst_name,
                        max(decode(b.statname,'DB time', round((b.value-a.value)/v_sampl_time))) dbtime,
                        max(decode(b.statname,'parse count (total)', round((b.value-a.value)/v_sampl_time))) Tparse,
                        max(decode(b.statname,'parse count (hard)', round((b.value-a.value)/v_sampl_time))) Hparse,
                        max(decode(b.statname,'physical write total IO requests', round((b.value-a.value)/v_sampl_time))) PhyWIO,
                        max(decode(b.statname,'physical write total bytes', round(((b.value-a.value)/1048576)/v_sampl_time))) PhyWMB,
                        max(decode(b.statname,'physical read total IO requests', round((b.value-a.value)/v_sampl_time))) PhyRIO,
                        max(decode(b.statname,'physical read total bytes', round(((b.value-a.value)/1048576)/v_sampl_time))) PhyRMB,
                        max(decode(b.statname,'session logical reads', round((b.value-a.value)/v_sampl_time))) SessLIO,
                        max(decode(b.statname,'execute count', round((b.value-a.value)/v_sampl_time))) TotExec,
                        max(decode(b.statname,'redo size', round(((b.value-a.value)/1048576)/v_sampl_time))) RedoMB,
                        max(decode(b.statname,'user commits', round((b.value-a.value)/v_sampl_time))) Ccommit,
                        sum(decode(b.statname,'IDLE_TIME', round((b.value-a.value)/v_sampl_time)))   idle_time,
                        sum(decode(b.statname,'USER_TIME', round((b.value-a.value)/v_sampl_time)))   user_time,
                        sum(decode(b.statname,'SYS_TIME',  round((b.value-a.value)/v_sampl_time)))    sys_time,
                        sum(decode(b.statname,'IOWAIT_TIME', round((b.value-a.value)/v_sampl_time))) iowait_time,
                        sum(decode(b.statname,'BUSY_TIME', round((b.value-a.value)/v_sampl_time)))   busy_time,
                        sum(decode(b.statname,'NICE_TIME', round((b.value-a.value)/v_sampl_time)))   nice_time,
                        sum(decode(b.statname,'cell physical IO interconnect bytes returned by smart scan', round(((b.value-a.value)/1048576)/v_sampl_time))) ExSSMB,
                        sum(decode(b.statname,'cell physical IO bytes saved by storage index', round(((b.value-a.value)/1048576)/v_sampl_time))) ExSIMB,
                        sum(decode(b.statname,'cell flash cache read hits', round(((b.value-a.value))/v_sampl_time))) ExFCRh,
                        sum(decode(b.statname,'gc cr blocks served', round(((b.value-a.value))/v_sampl_time)))        GCCRBS,
                        sum(decode(b.statname,'gc current blocks served', round(((b.value-a.value))/v_sampl_time)))   GCCUBS,
                        sum(decode(b.statname,'gc cr blocks received', round(((b.value-a.value))/v_sampl_time)))      GCCRBR,
                        sum(decode(b.statname,'gc current blocks received', round(((b.value-a.value))/v_sampl_time))) GCCUBR,
                        sum(decode(b.statname,'gcs msgs received', round(((b.value-a.value))/v_sampl_time))) GCSMR,
                        sum(decode(b.statname,'ges msgs received', round(((b.value-a.value))/v_sampl_time))) GESMR,
                        sum(decode(b.statname,'gcs messages sent', round(((b.value-a.value))/v_sampl_time))) GCSMS,
                        sum(decode(b.statname,'ges messages sent', round(((b.value-a.value))/v_sampl_time))) GESMS
                          from table(fv_lastsample)  b,
                                table(fv_firstsample) a
                           where a.inst_id = b.inst_id and
                                   a.statname   = b.statname   and
                                   a.inst_id = i.inst_id
                                   group by b.inst_id,b.inst_name
                          ) loop
            v_total_time :=  ii.idle_time+ii.busy_time;
            fv_ta_obj.extend;
            fv_ta_obj(fv_ta_obj.count) := ty_obj(
              '|'||
              rpad(substr(ii.inst_name,1,11),11,' ')||'|'||
              lpad(trunc(100-((ii.iowait_time+ii.user_time+ii.sys_time+ii.nice_time)/v_total_time*100),1)||' ',6,' ')||
              lpad(trunc(ii.iowait_time/v_total_time*100,1),5,' ')||' '||
              lpad(trunc(ii.user_time/v_total_time*100,1),5,' ')||' '||
              lpad(trunc(ii.sys_time/v_total_time*100,1),5,' ')||'|'||
              lpad(ii.Tparse,11,' ')||'|'||
              lpad(ii.Hparse,7,' ')||'|'||
              lpad(ii.Phywio,11,' ')||'|'||
              lpad(ii.phywmb,10,' ')||'|'||
              lpad(ii.phyrio,12,' ')||'|'||
              lpad(ii.phyrmb,10,' ')||'|'||
              lpad(ii.sesslio,12,' ')||'|'||
              lpad(ii.totexec,10,' ')||'|'||
              lpad(ii.redomb,8,' ')||'|'||
              lpad(ii.ccommit,8,' ')||'|'||
              lpad(ii.ExSSMB,10,' ')||'|'||
              lpad(ii.ExSIMB,9,' ')||'|'||
              lpad(ii.ExFCRh,9,' ')||'|'
              ) ;

      -- Filling GC data into global array for later use., info for columns related to gc* waits
            pv_only_gc.extend;
            pv_only_gc(pv_only_gc.count) := ty_gc(ii.inst_id,ii.GCCRBS+ii.GCCUBS,ii.GCCRBR+ii.GCCRBR,ii.GCSMR+ii.GESMR+ii.GCSMS+ii.GESMS);

          -------------- Getting Total/sum
            vt_tprse   :=  vt_tprse + ii.tparse;
            vt_hprse   :=  vt_hprse + ii.hparse;
            vt_phwio   :=  vt_phwio + ii.phywio;
            vt_phwmb   :=  vt_phwmb + ii.phywmb;
            vt_phrio   :=  vt_phrio + ii.phyrio;
            vt_phrmb   :=  vt_phrmb + ii.phyrmb;
            vt_slio    :=  vt_slio  + ii.sesslio;
            vt_exec    :=  vt_exec  + ii.totexec;
            vt_redo    :=  vt_redo  + ii.redomb;
            vt_comt    :=  vt_comt  + ii.ccommit;
            vt_exSS    :=  vt_exSS  + ii.ExSSMB;
            vt_exSI    :=  vt_exSI  + ii.ExSIMB;
            vt_exFC    :=  vt_exFC  + ii.ExFCRh;
         --------------
          end loop;

   end loop;
  -------
     fv_ta_obj.extend;
     fv_ta_obj(fv_ta_obj.count) := ty_obj( '+-----------+-----------------------+-----------+-------+-----------+----------+------------+----------+------------+----------+--------+--------+----------+---------+---------+'  )  ;

     fv_ta_obj.extend;
     fv_ta_obj(fv_ta_obj.count) := ty_obj( '                              TOTAL :'||
              lpad(vt_tprse,11,' ')||','||
              lpad(vt_hprse,7,' ')||','||
              lpad(vt_phwio,11,' ')||','||
              lpad(vt_phwmb,10,' ')||','||
              lpad(vt_phrio,12,' ')||','||
              lpad(vt_phrmb,10,' ')||','||
              lpad(vt_slio,12,' ')||','||
              lpad(vt_exec,10,' ')||','||
              lpad(vt_redo,8,' ')||','||
              lpad(vt_comt,8,' ')||','||
              lpad(vt_ExSS,10,' ')||','||
              lpad(vt_ExSI,9,' ')||','||
              lpad(vt_ExFC,9,' ')||',' );
return fv_ta_obj;
exception
when others then
raise_application_Error(-20001,'GINSTBUILDDATA: '||sqlerrm );
end;
-------------------/





------##################
-- gash - build dataset from gv$active_Session_history for the given sample time,
-- added logic to eliminate the own session info
------##################
function gash (fv_st_smpltime date,fv_et_smpltime date) return ta_gash
is
fv_gash    ta_gash := ta_gash();
fv_sql     varchar2(2000) :=
 q'[select ty_gash(gash.Inst_id,gash.session_id,gash.sql_id,gash.sql_child_number, substr(sql_Text,1,100), null,
                                case when session_state = 'WAITING' then gash.event else 'ON CPU' end,
                                case when session_state = 'WAITING' then gash.wait_class else 'ON CPU' end,
                                gash.delta_Time,
                                gash.current_obj# )
                                from gv$active_Session_history gash, gv$sql gsql
                                where  gash.sample_time between :fv_st_smpltime and :fv_et_smpltime
                                and  gash.program not like '%(PZ%'
                                and  gash.delta_time > 0
                                and (gash.wait_class != 'Idle' or gash.session_state != 'WAITING')
                                and  gash.inst_id||':'||gash.session_id != sys_context('userenv','INSTANCE')||':'||sys_context('userenv','SID')
                                and gash.inst_id = gsql.inst_id and gash.sql_id=gsql.sql_id
                               ]';



begin
execute immediate fv_sql bulk collect into fv_gash using fv_st_smpltime,fv_et_smpltime;
return fv_gash;
end;
-------------------/





------##################
-- gashbuilddata - it access data from collection pv_only_gash built in gash function for given sample
------##################
function gashbuilddata (fv_only_gash ta_gash ) return ta_obj
is
fv_ta_obj      ta_obj := ta_obj();

fv_wait_obj    ta_obj := ta_obj();
fv_sql_obj     ta_obj := ta_obj();

fv_output      varchar2(200);
fv_sid_string  varchar2(66);

begin

--js resetting graph wait variables
pv_cpuwaitpct := 0;
pv_iowaitpct  := 0;
pv_cluwaitpct := 0;
pv_othwaitpct := 0;
------------

pv_top_sql.delete;

              --- getting top 5 events based on time spent event wise
          for i in (select pct,event,wait_class from (
                           select wait_class,event, round(evnttime/tottime * 100,1) pct from
                                (select wait_class,event, sum(time_waited) evnttime from table(fv_only_gash)
                                where event is not null group by wait_class, event ) evnt,
                          (select sum(time_Waited) tottime from table(fv_only_gash )) tot
                                                order by pct desc
                     ) where rownum < 6
                    ) loop
                        fv_Wait_obj.extend;
                        fv_wait_obj(fv_wait_obj.count) :=  ty_obj('| '||lpad(round(i.pct,1)||'%',6,' ')||' | '||rpad(substr(i.event,1,38),38,' ')||' | '||rpad(i.wait_class,17,' ')||' |' ) ;

                  -------------- Storing info in 4 variables to get the % of of all the waits for total active sessions for graph
                   case
                   when i.wait_class = 'ON CPU'      then pv_cpuwaitpct :=   (pv_cpuwaitpct + i.pct);
                   when i.wait_class = 'User I/O'    then pv_iowaitpct  :=   (pv_iowaitpct  + i.pct);
                   when i.wait_class = 'System I/O'  then pv_iowaitpct  :=   (pv_iowaitpct  + i.pct);
                   when i.wait_class = 'Cluster'     then pv_cluwaitpct :=   (pv_cluwaitpct + i.pct);
                   ELSE
                        pv_othwaitpct := ( pv_othwaitpct + i.pct );
                   end case;
                  -------------

         end loop;

              --- getting top 5 sqls based on time spent event wise
 for ii in ( select pct,sql_id||'('||sql_child||')' sql_id from (
             select  sql_id,sql_child, round(sqltime/tottime * 100,1) pct from
               (select sql_id,sql_child, sum(time_waited) sqltime from  table(fv_only_gash)
                     where sql_id is not null group by sql_id,sql_child ) sqlt,
               (select sum(time_Waited) tottime from  table(fv_only_gash)) tot
                                        order by pct desc
                                      ) where rownum < 6
            ) loop
               --- building inst_id and sid string for top sqls
           select substr(sidstring,1,66) into fv_sid_string from (
            select  listagg(inst_id||':'||sid,', ') within group ( order by  sql_id||'('||sql_child||')' ) sidstring
            from (select distinct sql_id,sql_child,inst_id,sid from table(fv_only_gash) where sql_id||'('||sql_child||')' = ii.sql_id  ) );

            fv_sql_obj.extend;
            fv_sql_obj(fv_sql_obj.count)  :=  ty_obj('       | '||lpad(round(ii.pct,1)||'%',6,' ')||' | '||rpad(ii.sql_id,17,' ')||' | '||rpad(fv_sid_string,66,' ')||' |' );

                --- filling global collection pv_top_sql for later use
           pv_top_sql.extend; pv_top_sql(pv_Top_sql.count) := ty_obj(substr(ii.sql_id,1,13));
 end loop;

  fv_ta_obj.extend;
  fv_ta_obj(fv_ta_obj.count) := ty_obj('+IMPACT%-+--TOP WAIT EVENTS-----------------------+-WAIT CLASS--------+       +IMPACT%-+ TOP SQLS (child)--+-TOP SESSIONS-------INST:SID----------------------------------------+' ) ;

      -- printing top wait events and top sqls
  for iii in 1..greatest(fv_wait_obj.count,fv_sql_obj.count) loop
             if fv_wait_obj.exists(iii) then
                     fv_output := fv_wait_obj(iii).output;
                     else
                     fv_output := '| '||lpad(' ',6,' ')||' | '||rpad(' ',38,' ')||' | '||rpad(' ',17,' ')||' |' ;
             end if;

             if fv_sql_obj.exists(iii) then
                     fv_output := fv_output||fv_sql_obj(iii).output;
                     else
                     fv_output := fv_output||'       | '||lpad(' ',6,' ')||' | '||rpad(' ',17,' ')||' | '||rpad(' ',66,' ')||' |' ;
             end if;
             fv_ta_obj.extend;
             fv_ta_obj(fv_ta_obj.count) := ty_obj(fv_output);
  end loop;

  fv_ta_obj.extend;
  fv_ta_obj(fv_ta_obj.count) := ty_obj('+--------+----------------------------------------+-------------------+       +--------+-------------------+--------------------------------------------------------------------+' );

 -- adding emplty lines to getting fixed ASG [Active Session Graph ]
 for iv in 1..(7-fv_ta_obj.count) loop
   fv_ta_obj.extend;
   fv_ta_obj(fv_ta_obj.count):= ty_obj(' ');
   end loop;

return fv_ta_obj;
exception
when others then
raise_application_Error(-20001,'GASH: '||sqlerrm );
end;
-------------------/





------##################
-- Gcinfo uses pv_only_gc collection built by ginstbuilddata to format
------##################
function gcinfo return ta_obj
as
fv_gcs     ta_obj := ta_obj();
fv_topgseg ta_obj := ta_obj();
fv_ta_obj  ta_obj := ta_obj();
fv_seg              varchar2(40);
fv_totblks           int;
fv_totmsgs           int;
begin

------------------------------
-- *BASED on AWR, below formula can be used to calculate  Estd interconnect Traffic
------------------------------
/*
Estd Interconnect traffic (KB): =(('gc cr blocks received' + 'gc current blocks received' + 'gc cr blocks served' + 'gc current blocks served') * db Block size)
+ (('gcs messages sent' + 'ges messages sent' + 'gcs msgs received' + 'ges msgs received' )* 200 )/1024/

 -- Sample Calculation from AWR using Above Formula

 Global Cache Load Profile
~~~~~~~~~~~~~~~~~~~~~~~~                  Per Second       Per Transact
                                      ---------------       ------------
  Global Cache blocks received:              1,086.29                  3
    Global Cache blocks served:              1,088.33                  3
     GCS/GES messages received:              2,736.50                  9
         GCS/GES messages sent:              2,681.79                  9
            DBWR Fusion writes:                  5.90                  0
 Estd Interconnect traffic (KB)             18,455.23

(( 1086.29 + 1088.33) * 8192 ) / 1024  = 17396.96
(( 2736.50 + 2681.79 ) * 200  / 1024  = 1058.26

 17396.96 + 1058.26  =  (18455.22) <-- Final Value
*/

--  pv_only_gc is being populated from ginstbuilddata function [ access gv$sysstat and gv$dlm_misc ] only for GC* waits
--  calculating totblks received/sent and total GCS/GES messages received/sent
for i in 1..pv_only_gc.count loop
fv_totblks :=  (nvl(pv_only_gc(i).GCBCS,0) + nvl(pv_only_gc(i).GCBRS,0)) * pv_block_size ;
fv_totmsgs :=   nvl(pv_only_gc(i).GMSR,0) * 200 ;

fv_gcs.extend;
fv_gcs(fv_gcs.count) := ty_obj ( lpad(pv_only_gc(i).inst_id,3,' ')||' | '||lpad(nvl(pv_only_gc(i).GCBCS,0),9,' ')||'|'||lpad(nvl(pv_only_gc(i).GCBRS,0),10,' ')||'|'||lpad(round( (  (fv_totblks+fv_totmsgs)/1048576),1),11,' ')||'|' );
end loop;

--
            --  querying pv_only_gash [ global active session history data for Cluster waits and using current_obj# to find the topobject
             for ii in (  select * from ( select   obj#, round(evnttime/tottime * 100,1) pct from
                             (select  obj#,sum(time_waited) evnttime from table(pv_only_gash) where wait_class = 'Cluster' and  obj# != -1 group by obj# ) gcobj,
                            (select sum(time_Waited) tottime from table(pv_only_gash ) where wait_class = 'Cluster' and  obj# != -1 ) tot
                                                    order by pct desc
                                                    ) where rownum < 6

                        ) loop
            begin

            --- getting object name from gv$segment_statistics

            select rpad( (substr(s.object_type,1,3)||':'||substr(s.object_name||nvl2(subobject_name,':'||subobject_name,null),1,33)),37,' ') into fv_seg from gv$segment_statistics s where s.obj# = ii.obj# and rownum = 1;
            exception
            when no_data_found then
            fv_seg := 'Obj ID not populated' ;
            end;

            fv_topgseg.extend;
            fv_topgseg(fv_topgseg.count) := ty_obj (' |'||lpad(ii.pct||'%',5)||' '||fv_seg);
            end loop;
--
-- building header for Global Cache info
fv_ta_obj.extend;fv_ta_obj(fv_ta_obj.count) := ty_obj( '    |  Global  |  Global  | Estd.     |                            ');
fv_ta_obj.extend;fv_ta_obj(fv_ta_obj.count) := ty_obj( '    |  Cache   |  Cache   | Intercnt  |  | TOP Segments by GC*     |');
fv_ta_obj.extend;fv_ta_obj(fv_ta_obj.count) := ty_obj( 'Inst|  Blocks  |  Blocks  | Traffic   |  | Waits                   |');
fv_ta_obj.extend;fv_ta_obj(fv_ta_obj.count) := ty_obj( '  ID|  Sent/s  |  Rcvd/s  | MB/s      |  | IMPACT% [Type:Segment]  |');
fv_ta_obj.extend;fv_ta_obj(fv_ta_obj.count) := ty_obj( '+---+----------+----------+-----------+  +-------------------------+');


            for iii in 1..12 loop     -- Concatinating output about GC info and TOP Segment

               if fv_gcs.count < iii then fv_gcs.extend; end if;
               if fv_topgseg.count < iii then fv_topgseg.extend; end if;

            fv_ta_obj.extend; fv_ta_obj(fv_ta_obj.count) := ty_obj(rpad(nvl(fv_gcs(iii).output,' '),39,' ')||' '||fv_topgseg(iii).output );
            end loop;

return fv_ta_obj;

exception
when others then
raise_application_Error(-20001,'GCINFO : '||sqlerrm );
end ;
-------------------/




------##################
--   stactsessar - it shuffles all the arrays to have moving effect in ASG
--   it also rearrange the max sess based on the changed array range.
------##################
procedure stactsessarr
as

procedure setgraphdigit(p_varrlenset int, p_pa in out ta_obj )
as
begin
pv_work_done := 1 ;
pva := 0;
pvb := 0;
pvc := 0;
pvd := 0;
pve := 0;

 if to_number(p_pa(18).output) > 0 then    -- CPU
     p_localarray := round( p_varrlenset * to_number(p_pa(18).output ) / 100 ) ;
     if p_localarray > 0 then
          for i in pv_work_done..p_localarray loop
            p_pa(i) := ty_obj(pv_cpu_dig) ;
            end loop;
          pv_work_done := pv_work_done + p_localarray ;
     end if;
end if;


 if to_number(p_pa(19).output) > 0 then    -- IO
     p_localarray := round( p_varrlenset * to_number(p_pa(19).output ) / 100 ) ;
     if p_localarray > 0 then
          for i in pv_work_done..(pv_work_done + p_localarray) loop
            p_pa(i) := ty_obj(pv_io_dig) ;
          end loop;
          pv_work_done :=  pv_work_done + p_localarray ;
     end if;
end if;



 if to_number(p_pa(20).output) > 0 then    -- CLU
     p_localarray := round( p_varrlenset * to_number(p_pa(20).output ) / 100 ) ;
     if p_localarray > 0 then
          for i in pv_work_done..(pv_work_done + p_localarray) loop
            p_pa(i) := ty_obj(pv_CLU_dig) ;
          end loop;
          pv_work_done :=  pv_work_done + p_localarray ;
     end if;
end if;



 if to_number(p_pa(21).output) > 0 then    -- OTH
     p_localarray := round( p_varrlenset * to_number(p_pa(21).output ) / 100 ) ;
     if p_localarray > 0 then
          for i in pv_work_done..(pv_work_done + p_localarray) loop
            p_pa(i) := ty_obj(pv_oth_dig) ;
          end loop;
          pv_work_done :=  pv_work_done + p_localarray ;
     end if;
end if;


     for i in (p_varrlenset+1)..15 loop  --filling remaining array
       p_pa(i) := ty_obj(' ');
      end loop;
 end;


begin
 --- shuffling array except the first one
pa80 := pa79; pa79 := pa78; pa78 := pa77; pa77 := pa76; pa76 := pa75; pa75 := pa74; pa74 := pa73; pa73 := pa72; pa72 := pa71; pa71 := pa70;
pa70 := pa69; pa69 := pa68; pa68 := pa67; pa67 := pa66; pa66 := pa65; pa65 := pa64; pa64 := pa63; pa63 := pa62; pa62 := pa61; pa61 := pa60;
pa60 := pa59; pa59 := pa58; pa58 := pa57; pa57 := pa56; pa56 := pa55; pa55 := pa54; pa54 := pa53; pa53 := pa52; pa52 := pa51; pa51 := pa50;
pa50 := pa49; pa49 := pa48; pa48 := pa47; pa47 := pa46; pa46 := pa45; pa45 := pa44; pa44 := pa43; pa43 := pa42; pa42 := pa41; pa41 := pa40;
pa40 := pa39; pa39 := pa38; pa38 := pa37; pa37 := pa36; pa36 := pa35; pa35 := pa34; pa34 := pa33; pa33 := pa32; pa32 := pa31; pa31 := pa30;
pa30 := pa29; pa29 := pa28; pa28 := pa27; pa27 := pa26; pa26 := pa25; pa25 := pa24; pa24 := pa23; pa23 := pa22; pa22 := pa21; pa21 := pa20;
pa20 := pa19; pa19 := pa18; pa18 := pa17; pa17 := pa16; pa16 := pa15; pa15 := pa14; pa14:=pa13; pa13:=pa12; pa12:=pa11; pa11:=pa10;
pa10:= pa9; pa9:=pa8; pa8 :=pa7; pa7:=pa6; pa6:=pa5; pa5:=pa4; pa4:=pa3; pa3:=pa2; pa2:=pa1;

    -- updating first array
       pa1(21) := ty_obj(pv_othwaitpct);
       pa1(20) := ty_obj(pv_cluwaitpct);
       pa1(19) := ty_obj(pv_iowaitpct);
       pa1(18) := ty_obj(pv_cpuwaitpct);
       pa1(17) := ty_obj(pv_maxval);
       pa1(16) := ty_obj(pv_maxsess);
                                                                                                                              --- here else clause is used for the empty arrays when we start dashboard
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa1(16).output) then js_maxsess := to_number(pa1(16).output); js_arr := i-1;  setgraphdigit(i-1,pa1);  exit; else pa1(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa2(16).output) then setgraphdigit(i-1,pa2);  exit; else pa2(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa3(16).output) then setgraphdigit(i-1,pa3);  exit; else pa3(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa4(16).output) then setgraphdigit(i-1,pa4);  exit; else pa4(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa5(16).output) then setgraphdigit(i-1,pa5);  exit; else pa5(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa6(16).output) then setgraphdigit(i-1,pa6);  exit; else pa6(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa7(16).output) then setgraphdigit(i-1,pa7);  exit; else pa7(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa8(16).output) then setgraphdigit(i-1,pa8);  exit; else pa8(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa9(16).output) then setgraphdigit(i-1,pa9);  exit; else pa9(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa10(16).output) then setgraphdigit(i-1,pa10);  exit; else pa10(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa11(16).output) then setgraphdigit(i-1,pa11);  exit; else pa11(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa12(16).output) then setgraphdigit(i-1,pa12);  exit; else pa12(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa13(16).output) then setgraphdigit(i-1,pa13);  exit; else pa13(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa14(16).output) then setgraphdigit(i-1,pa14);  exit; else pa14(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa15(16).output) then setgraphdigit(i-1,pa15);  exit; else pa15(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa16(16).output) then setgraphdigit(i-1,pa16);  exit; else pa16(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa17(16).output) then setgraphdigit(i-1,pa17);  exit; else pa17(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa18(16).output) then setgraphdigit(i-1,pa18);  exit; else pa18(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa19(16).output) then setgraphdigit(i-1,pa19);  exit; else pa19(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa20(16).output) then setgraphdigit(i-1,pa20);  exit; else pa20(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa21(16).output) then setgraphdigit(i-1,pa21);  exit; else pa21(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa22(16).output) then setgraphdigit(i-1,pa22);  exit; else pa22(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa23(16).output) then setgraphdigit(i-1,pa23);  exit; else pa23(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa24(16).output) then setgraphdigit(i-1,pa24);  exit; else pa24(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa25(16).output) then setgraphdigit(i-1,pa25);  exit; else pa25(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa26(16).output) then setgraphdigit(i-1,pa26);  exit; else pa26(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa27(16).output) then setgraphdigit(i-1,pa27);  exit; else pa27(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa28(16).output) then setgraphdigit(i-1,pa28);  exit; else pa28(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa29(16).output) then setgraphdigit(i-1,pa29);  exit; else pa29(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa30(16).output) then setgraphdigit(i-1,pa30);  exit; else pa30(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa31(16).output) then setgraphdigit(i-1,pa31);  exit; else pa31(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa32(16).output) then setgraphdigit(i-1,pa32);  exit; else pa32(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa33(16).output) then setgraphdigit(i-1,pa33);  exit; else pa33(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa34(16).output) then setgraphdigit(i-1,pa34);  exit; else pa34(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa35(16).output) then setgraphdigit(i-1,pa35);  exit; else pa35(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa36(16).output) then setgraphdigit(i-1,pa36);  exit; else pa36(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa37(16).output) then setgraphdigit(i-1,pa37);  exit; else pa37(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa38(16).output) then setgraphdigit(i-1,pa38);  exit; else pa38(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa39(16).output) then setgraphdigit(i-1,pa39);  exit; else pa39(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa40(16).output) then setgraphdigit(i-1,pa40);  exit; else pa40(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa41(16).output) then setgraphdigit(i-1,pa41);  exit; else pa41(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa42(16).output) then setgraphdigit(i-1,pa42);  exit; else pa42(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa43(16).output) then setgraphdigit(i-1,pa43);  exit; else pa43(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa44(16).output) then setgraphdigit(i-1,pa44);  exit; else pa44(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa45(16).output) then setgraphdigit(i-1,pa45);  exit; else pa45(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa46(16).output) then setgraphdigit(i-1,pa46);  exit; else pa46(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa47(16).output) then setgraphdigit(i-1,pa47);  exit; else pa47(i) := ty_obj(' ');   end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa48(16).output) then setgraphdigit(i-1,pa48);  exit; else pa48(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa49(16).output) then setgraphdigit(i-1,pa49);  exit; else pa49(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa50(16).output) then setgraphdigit(i-1,pa50);  exit; else pa50(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa51(16).output) then setgraphdigit(i-1,pa51);  exit; else pa51(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa52(16).output) then setgraphdigit(i-1,pa52);  exit; else pa52(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa53(16).output) then setgraphdigit(i-1,pa53);  exit; else pa53(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa54(16).output) then setgraphdigit(i-1,pa54);  exit; else pa54(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa55(16).output) then setgraphdigit(i-1,pa55);  exit; else pa55(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa56(16).output) then setgraphdigit(i-1,pa56);  exit; else pa56(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa57(16).output) then setgraphdigit(i-1,pa57);  exit; else pa57(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa58(16).output) then setgraphdigit(i-1,pa58);  exit; else pa58(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa59(16).output) then setgraphdigit(i-1,pa59);  exit; else pa59(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa60(16).output) then setgraphdigit(i-1,pa60);  exit; else pa60(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa61(16).output) then setgraphdigit(i-1,pa61);  exit; else pa61(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa62(16).output) then setgraphdigit(i-1,pa62);  exit; else pa62(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa63(16).output) then setgraphdigit(i-1,pa63);  exit; else pa63(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa64(16).output) then setgraphdigit(i-1,pa64);  exit; else pa64(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa65(16).output) then setgraphdigit(i-1,pa65);  exit; else pa65(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa66(16).output) then setgraphdigit(i-1,pa66);  exit; else pa66(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa67(16).output) then setgraphdigit(i-1,pa67);  exit; else pa67(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa68(16).output) then setgraphdigit(i-1,pa68);  exit; else pa68(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa69(16).output) then setgraphdigit(i-1,pa69);  exit; else pa69(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa70(16).output) then setgraphdigit(i-1,pa70);  exit; else pa70(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa71(16).output) then setgraphdigit(i-1,pa71);  exit; else pa71(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa72(16).output) then setgraphdigit(i-1,pa72);  exit; else pa72(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa73(16).output) then setgraphdigit(i-1,pa73);  exit; else pa73(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa74(16).output) then setgraphdigit(i-1,pa74);  exit; else pa74(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa75(16).output) then setgraphdigit(i-1,pa75);  exit; else pa75(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa76(16).output) then setgraphdigit(i-1,pa76);  exit; else pa76(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa77(16).output) then setgraphdigit(i-1,pa77);  exit; else pa77(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa78(16).output) then setgraphdigit(i-1,pa78);  exit; else pa78(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa79(16).output) then setgraphdigit(i-1,pa79);  exit; else pa79(i) := ty_obj(' ');  end if;  end loop;
      for i in 1..15 loop  if to_number(pa_stet(i).output) > to_number(pa80(16).output) then setgraphdigit(i-1,pa80);  exit; else pa80(i) := ty_obj(' ');  end if;  end loop;

                for i in 2..15 loop
               if pv_num_cpus < to_number(pa_stet(i).output) then
                   pv_maxcpuprint := pa_stet(i-1).output;  exit; end if;
               end loop;

               -- printing exact active sess
               pa81.delete; pa81.extend(15);
               pa82.delete; pa82.extend(15);
               pa83.delete; pa83.extend(15);
               pa84.delete; pa84.extend(15);
               for i in 1..15 loop
               if  pa1(i).output in (pv_cpu_dig,pv_io_dig,pv_clu_dig,pv_oth_dig) then
                 null; -- need to add logic
                 else
                   if i > 1 then -- protecting being no active session
                   pa81(i-1) := ty_obj(substr(lpad(pv_maxsess,4,'_'),1,1));
                   pa82(i-1) := ty_obj(substr(lpad(pv_maxsess,4,'_'),2,1));
                   pa83(i-1) := ty_obj(substr(lpad(pv_maxsess,4,'_'),3,1));
                   pa84(i-1) := ty_obj(substr(lpad(pv_maxsess,4,'_'),4,1));
                   end if;
                 exit;
                 end if;
               end loop;

exception
when others then
raise_application_Error(-20001,'STACTSESSAR : '||sqlerrm || '  '|| pv_work_done ) ;

end;
-------------------/





------##################
-- gactses : it set the upper bound of array based on
-- no. of active sessions and add 15%
-- it also builds the range of sessions
------##################
Procedure gactses
is
begin

       -- Max active session at this point
       select  count (distinct ( inst_id||':'||sid )) into  pv_maxsess  from  table(pv_only_gash);


          -- Setting MAx VALUE top of CPU Vs Active sess and adding 15% -
        select case when round (max(pv_maxsess+(pv_maxsess*15/100))) < 15 then 15 else round (max(pv_maxsess+(pv_maxsess*15/100))) end  maxval  into pv_maxval from dual;


        --- searching if any existing array has got higher value.
             pv_tmp_maxval := greatest(pv_maxval,nvl(pa1(17).output,0),nvl(pa2(17).output,0),nvl(pa3(17).output,0),nvl(pa4(17).output,0),
              nvl(pa5(17).output,0),nvl(pa6(17).output,0), nvl(pa7(17).output,0),nvl(pa8(17).output,0),nvl(pa9(17).output,0),nvl(pa10(17).output,0),nvl(pa11(17).output,0),
              nvl(pa12(17).output,0),nvl(pa13(17).output,0),nvl(pa14(17).output,0),nvl(pa15(17).output,0)
             ,nvl(pa16(17).output,0) ,nvl(pa17(17).output,0) ,nvl(pa18(17).output,0) ,nvl(pa19(17).output,0) ,nvl(pa20(17).output,0)
            ,nvl(pa21(17).output,0) ,nvl(pa22(17).output,0) ,nvl(pa23(17).output,0) ,nvl(pa24(17).output,0) ,nvl(pa25(17).output,0)
            ,nvl(pa26(17).output,0) ,nvl(pa27(17).output,0) ,nvl(pa28(17).output,0) ,nvl(pa29(17).output,0) ,nvl(pa30(17).output,0)
            ,nvl(pa31(17).output,0) ,nvl(pa32(17).output,0) ,nvl(pa33(17).output,0) ,nvl(pa34(17).output,0) ,nvl(pa35(17).output,0)
            ,nvl(pa36(17).output,0) ,nvl(pa37(17).output,0) ,nvl(pa38(17).output,0) ,nvl(pa39(17).output,0) ,nvl(pa40(17).output,0)
            ,nvl(pa41(17).output,0) ,nvl(pa42(17).output,0) ,nvl(pa43(17).output,0) ,nvl(pa44(17).output,0) ,nvl(pa45(17).output,0)
            ,nvl(pa46(17).output,0) ,nvl(pa47(17).output,0) ,nvl(pa48(17).output,0) ,nvl(pa49(17).output,0) ,nvl(pa50(17).output,0)
            ,nvl(pa51(17).output,0) ,nvl(pa52(17).output,0) ,nvl(pa53(17).output,0) ,nvl(pa54(17).output,0) ,nvl(pa55(17).output,0)
            ,nvl(pa56(17).output,0) ,nvl(pa57(17).output,0) ,nvl(pa58(17).output,0) ,nvl(pa59(17).output,0) ,nvl(pa60(17).output,0)
            ,nvl(pa61(17).output,0) ,nvl(pa62(17).output,0) ,nvl(pa63(17).output,0) ,nvl(pa64(17).output,0) ,nvl(pa65(17).output,0)
            ,nvl(pa66(17).output,0) ,nvl(pa67(17).output,0) ,nvl(pa68(17).output,0) ,nvl(pa69(17).output,0) ,nvl(pa70(17).output,0)
            ,nvl(pa71(17).output,0) ,nvl(pa72(17).output,0) ,nvl(pa73(17).output,0) ,nvl(pa74(17).output,0) ,nvl(pa75(17).output,0)
            ,nvl(pa76(17).output,0) ,nvl(pa77(17).output,0) ,nvl(pa78(17).output,0) ,nvl(pa79(17).output,0) ,nvl(pa80(17).output,0)
              );

          -- Fill Start/End array to print
             pa_stet.delete;
             select  ty_obj(val) bulk collect into pa_stet from (
                                                   select ceil(rownum * (pv_tmp_maxval/14)) val from dict where rownum < 15
                                                   union all
                                                   select 1 from dual
                                                               ) order by val  ;
             pa_stet.extend;
             pa_stet.extend;


stactsessarr;   -- calls stactsessarr to shuffle all the arrays to have moving effect
exception
when others then
raise_application_Error(-20001,'GACTSES : '||sqlerrm );
end;
-------------------/




------##################
-- gactsesret : it uses all global pa* arrays to format Active Session Graph
------##################
function gactsessret return ta_obj
as
fv_ta_obj  ta_obj := ta_obj();
begin
fv_Ta_obj.extend(18);

fv_ta_obj(1) :=ty_obj(rpad(' ',71,' ')||'        -------+'||'                                 ACTIVE SESSIONS GRAPH                              +----');


fv_ta_obj(2)  :=ty_obj(rpad(' ',71,' ')||'  Active'||lpad(pa_stet(15).output,6,' ')||' |'||(
pa80(15).output||pa79(15).output||pa78(15).output||pa77(15).output||pa76(15).output||pa75(15).output||pa74(15).output||pa73(15).output||pa72(15).output||pa71(15).output||pa70(15).output||pa69(15).output||pa68(15).output||pa67(15).output||pa66(15).output||pa65(15).output||pa64(15).output||pa63(15).output||
pa62(15).output||pa61(15).output||pa60(15).output||pa59(15).output||pa58(15).output||pa57(15).output||pa56(15).output||pa55(15).output||pa54(15).output||pa53(15).output||pa52(15).output||pa51(15).output||pa50(15).output||pa49(15).output||pa48(15).output||pa47(15).output||pa46(15).output||pa45(15).output||
pa44(15).output||pa43(15).output||pa42(15).output||pa41(15).output||pa40(15).output||pa39(15).output||pa38(15).output||pa37(15).output||pa36(15).output||pa35(15).output||pa34(15).output||pa33(15).output||pa32(15).output||pa31(15).output||pa30(15).output||pa29(15).output||pa28(15).output||pa27(15).output||
pa26(15).output||pa25(15).output||pa24(15).output||pa23(15).output||pa22(15).output||pa21(15).output||pa20(15).output||pa19(15).output||pa18(15).output||pa17(15).output||pa16(15).output||pa15(15).output||pa14(15).output||pa13(15).output||pa12(15).output||pa11(15).output||pa10(15).output||pa9(15).output||
pa8(15).output||pa7(15).output||pa6(15).output||pa5(15).output||pa4(15).output||pa3(15).output||pa2(15).output||pa1(15).output)||rpad(nvl(pa81(15).output||pa82(15).output||pa83(15).output||pa84(15).output,' '),4,' ')||'| '||rpad(pa_stet(15).output,6,' '));
if pv_maxcpuprint = pa_stet(15).output then  fv_ta_obj(2) :=ty_obj( substr(fv_ta_obj(2).output,1,100)||'-MAX CPUs ['||pv_num_cpus||']-'||substr(fv_ta_obj(2).output,length('-MAX CPUs ['||pv_num_cpus||']-')+101  )); end if;


fv_ta_obj(3)  :=ty_obj(rpad(substr(pv_tmp_gcinfo(1).output,1,71),71,' ')||'Sessions'||lpad(pa_stet(14).output,6,' ')||' |'||(
pa80(14).output||pa79(14).output||pa78(14).output||pa77(14).output||pa76(14).output||pa75(14).output||pa74(14).output||pa73(14).output||pa72(14).output||pa71(14).output||pa70(14).output||pa69(14).output||pa68(14).output||pa67(14).output||pa66(14).output||pa65(14).output||pa64(14).output||pa63(14).output||
pa62(14).output||pa61(14).output||pa60(14).output||pa59(14).output||pa58(14).output||pa57(14).output||pa56(14).output||pa55(14).output||pa54(14).output||pa53(14).output||pa52(14).output||pa51(14).output||pa50(14).output||pa49(14).output||pa48(14).output||pa47(14).output||pa46(14).output||pa45(14).output||
pa44(14).output||pa43(14).output||pa42(14).output||pa41(14).output||pa40(14).output||pa39(14).output||pa38(14).output||pa37(14).output||pa36(14).output||pa35(14).output||pa34(14).output||pa33(14).output||pa32(14).output||pa31(14).output||pa30(14).output||pa29(14).output||pa28(14).output||pa27(14).output||
pa26(14).output||pa25(14).output||pa24(14).output||pa23(14).output||pa22(14).output||pa21(14).output||pa20(14).output||pa19(14).output||pa18(14).output||pa17(14).output||pa16(14).output||pa15(14).output||pa14(14).output||pa13(14).output||pa12(14).output||pa11(14).output||pa10(14).output||pa9(14).output||
pa8(14).output||pa7(14).output||pa6(14).output||pa5(14).output||pa4(14).output||pa3(14).output||pa2(14).output||pa1(14).output)||rpad(nvl(pa81(14).output||pa82(14).output||pa83(14).output||pa84(14).output,' '),4,' ')||'| '||rpad(pa_stet(14).output,6,' ')||'           ' );
if pv_maxcpuprint = pa_stet(14).output then  fv_ta_obj(3) :=ty_obj( substr(fv_ta_obj(3).output,1,100)||'-MAX CPUs ['||pv_num_cpus||']-'||substr(fv_ta_obj(3).output,length('-MAX CPUs ['||pv_num_cpus||']-')+101  )); end if;


fv_ta_obj(4)  :=ty_obj(rpad(substr(pv_tmp_gcinfo(2).output,1,71),71,' ')||'        '||lpad(pa_stet(13).output,6,' ')||' |'||(
pa80(13).output||pa79(13).output||pa78(13).output||pa77(13).output||pa76(13).output||pa75(13).output||pa74(13).output||pa73(13).output||pa72(13).output||pa71(13).output||pa70(13).output||pa69(13).output||pa68(13).output||pa67(13).output||pa66(13).output||pa65(13).output||pa64(13).output||pa63(13).output||
pa62(13).output||pa61(13).output||pa60(13).output||pa59(13).output||pa58(13).output||pa57(13).output||pa56(13).output||pa55(13).output||pa54(13).output||pa53(13).output||pa52(13).output||pa51(13).output||pa50(13).output||pa49(13).output||pa48(13).output||pa47(13).output||pa46(13).output||pa45(13).output||
pa44(13).output||pa43(13).output||pa42(13).output||pa41(13).output||pa40(13).output||pa39(13).output||pa38(13).output||pa37(13).output||pa36(13).output||pa35(13).output||pa34(13).output||pa33(13).output||pa32(13).output||pa31(13).output||pa30(13).output||pa29(13).output||pa28(13).output||pa27(13).output||
pa26(13).output||pa25(13).output||pa24(13).output||pa23(13).output||pa22(13).output||pa21(13).output||pa20(13).output||pa19(13).output||pa18(13).output||pa17(13).output||pa16(13).output|| pa15(13).output||pa14(13).output||pa13(13).output||pa12(13).output||pa11(13).output||pa10(13).output||pa9(13).output||
pa8(13).output||pa7(13).output||pa6(13).output||pa5(13).output||pa4(13).output||pa3(13).output||pa2(13).output||pa1(13).output)||rpad(nvl(pa81(13).output||pa82(13).output||pa83(13).output||pa84(13).output,' '),4,' ')||'| '||rpad(pa_stet(13).output,6,' ')||'           ' );
if pv_maxcpuprint = pa_stet(13).output then  fv_ta_obj(4) :=ty_obj( substr(fv_ta_obj(4).output,1,100)||'-MAX CPUs ['||pv_num_cpus||']-'||substr(fv_ta_obj(4).output,length('-MAX CPUs ['||pv_num_cpus||']-')+101  )); end if;


fv_ta_obj(5)  :=ty_obj(rpad(substr(pv_tmp_gcinfo(3).output,1,71),71,' ')||'        '||lpad(pa_stet(12).output,6,' ')||' |'||(
pa80(12).output||pa79(12).output||pa78(12).output||pa77(12).output||pa76(12).output||pa75(12).output||pa74(12).output||pa73(12).output||pa72(12).output||pa71(12).output||pa70(12).output||pa69(12).output||pa68(12).output||pa67(12).output||pa66(12).output||pa65(12).output||pa64(12).output||pa63(12).output||
pa62(12).output||pa61(12).output||pa60(12).output||pa59(12).output||pa58(12).output||pa57(12).output||pa56(12).output||pa55(12).output||pa54(12).output||pa53(12).output||pa52(12).output||pa51(12).output||pa50(12).output||pa49(12).output||pa48(12).output||pa47(12).output||pa46(12).output||pa45(12).output||
pa44(12).output||pa43(12).output||pa42(12).output||pa41(12).output||pa40(12).output||pa39(12).output||pa38(12).output||pa37(12).output||pa36(12).output||pa35(12).output||pa34(12).output||pa33(12).output||pa32(12).output||pa31(12).output||pa30(12).output||pa29(12).output||pa28(12).output||pa27(12).output||
pa26(12).output||pa25(12).output||pa24(12).output||pa23(12).output||pa22(12).output||pa21(12).output||pa20(12).output||pa19(12).output||pa18(12).output||pa17(12).output||pa16(12).output||pa15(12).output||pa14(12).output||pa13(12).output||pa12(12).output||pa11(12).output||pa10(12).output||pa9(12).output||
pa8(12).output||pa7(12).output||pa6(12).output||pa5(12).output||pa4(12).output||pa3(12).output||pa2(12).output||pa1(12).output)||rpad(nvl(pa81(12).output||pa82(12).output||pa83(12).output||pa84(12).output,' '),4,' ')||'| '||rpad(pa_stet(12).output,6,' ')||'           ' );
if pv_maxcpuprint = pa_stet(12).output then  fv_ta_obj(5) :=ty_obj( substr(fv_ta_obj(5).output,1,100)||'-MAX CPUs ['||pv_num_cpus||']-'||substr(fv_ta_obj(5).output,length('-MAX CPUs ['||pv_num_cpus||']-')+101  )); end if;


fv_ta_obj(6)  :=ty_obj(rpad(substr(pv_tmp_gcinfo(4).output,1,71),71,' ')||'        '||lpad(pa_stet(11).output,6,' ')||' |'||(
pa80(11).output||pa79(11).output||pa78(11).output||pa77(11).output||pa76(11).output||pa75(11).output||pa74(11).output||pa73(11).output||pa72(11).output||pa71(11).output||pa70(11).output||pa69(11).output||pa68(11).output||pa67(11).output||pa66(11).output||pa65(11).output||pa64(11).output||pa63(11).output||
pa62(11).output||pa61(11).output||pa60(11).output||pa59(11).output||pa58(11).output||pa57(11).output||pa56(11).output||pa55(11).output||pa54(11).output||pa53(11).output||pa52(11).output||pa51(11).output||pa50(11).output||pa49(11).output||pa48(11).output||pa47(11).output||pa46(11).output||pa45(11).output||
pa44(11).output||pa43(11).output||pa42(11).output||pa41(11).output||pa40(11).output||pa39(11).output||pa38(11).output||pa37(11).output||pa36(11).output||pa35(11).output||pa34(11).output||pa33(11).output||pa32(11).output||pa31(11).output||pa30(11).output||pa29(11).output||pa28(11).output||pa27(11).output||
pa26(11).output||pa25(11).output||pa24(11).output||pa23(11).output||pa22(11).output||pa21(11).output||pa20(11).output||pa19(11).output||pa18(11).output||pa17(11).output||pa16(11).output||pa15(11).output||pa14(11).output||pa13(11).output||pa12(11).output||pa11(11).output||pa10(11).output||pa9(11).output||
pa8(11).output||pa7(11).output||pa6(11).output||pa5(11).output||pa4(11).output||pa3(11).output||pa2(11).output||pa1(11).output)||rpad(nvl(pa81(11).output||pa82(11).output||pa83(11).output||pa84(11).output,' '),4,' ')||'| '||rpad(pa_stet(11).output,6,' ')||'           ' );
if pv_maxcpuprint = pa_stet(11).output then  fv_ta_obj(6) :=ty_obj( substr(fv_ta_obj(6).output,1,100)||'-MAX CPUs ['||pv_num_cpus||']-'||substr(fv_ta_obj(6).output,length('-MAX CPUs ['||pv_num_cpus||']-')+101  )); end if;


fv_ta_obj(7)  :=ty_obj(rpad(substr(pv_tmp_gcinfo(5).output,1,71),71,' ')||'        '||lpad(pa_stet(10).output,6,' ')||' |'||(
pa80(10).output||pa79(10).output||pa78(10).output||pa77(10).output||pa76(10).output||pa75(10).output||pa74(10).output||pa73(10).output||pa72(10).output||pa71(10).output||pa70(10).output||pa69(10).output||pa68(10).output||pa67(10).output||pa66(10).output||pa65(10).output||pa64(10).output||pa63(10).output||
pa62(10).output||pa61(10).output||pa60(10).output||pa59(10).output||pa58(10).output||pa57(10).output||pa56(10).output||pa55(10).output||pa54(10).output||pa53(10).output||pa52(10).output||pa51(10).output||pa50(10).output||pa49(10).output||pa48(10).output||pa47(10).output||pa46(10).output||pa45(10).output||
pa44(10).output||pa43(10).output||pa42(10).output||pa41(10).output||pa40(10).output||pa39(10).output||pa38(10).output||pa37(10).output||pa36(10).output||pa35(10).output||pa34(10).output||pa33(10).output||pa32(10).output||pa31(10).output||pa30(10).output||pa29(10).output||pa28(10).output||pa27(10).output||
pa26(10).output||pa25(10).output||pa24(10).output||pa23(10).output||pa22(10).output||pa21(10).output||pa20(10).output||pa19(10).output||pa18(10).output||pa17(10).output||pa16(10).output||pa15(10).output||pa14(10).output||pa13(10).output||pa12(10).output||pa11(10).output||pa10(10).output||pa9(10).output||
pa8(10).output||pa7(10).output||pa6(10).output||pa5(10).output||pa4(10).output||pa3(10).output||pa2(10).output||pa1(10).output)||rpad(nvl(pa81(10).output||pa82(10).output||pa83(10).output||pa84(10).output,' '),4,' ')||'| '||rpad(pa_stet(10).output,6,' ')||'           ' );
if pv_maxcpuprint = pa_stet(10).output then  fv_ta_obj(7) :=ty_obj( substr(fv_ta_obj(7).output,1,100)||'-MAX CPUs ['||pv_num_cpus||']-'||substr(fv_ta_obj(7).output,length('-MAX CPUs ['||pv_num_cpus||']-')+101  )); end if;


fv_ta_obj(8)  :=ty_obj(rpad(substr(pv_tmp_gcinfo(6).output,1,77),77,' ')||'  '||lpad(pa_stet(9).output,6,' ')||' |'||(
pa80(9).output||pa79(9).output||pa78(9).output||pa77(9).output||pa76(9).output||pa75(9).output||pa74(9).output||pa73(9).output||pa72(9).output||pa71(9).output||pa70(9).output||pa69(9).output||pa68(9).output||pa67(9).output||pa66(9).output||pa65(9).output||pa64(9).output||pa63(9).output||pa62(9).output||
pa61(9).output||pa60(9).output||pa59(9).output||pa58(9).output||pa57(9).output||pa56(9).output||pa55(9).output||pa54(9).output||pa53(9).output||pa52(9).output||pa51(9).output||pa50(9).output||pa49(9).output||pa48(9).output||pa47(9).output||pa46(9).output||pa45(9).output||pa44(9).output||pa43(9).output||
pa42(9).output||pa41(9).output||pa40(9).output||pa39(9).output||pa38(9).output||pa37(9).output||pa36(9).output||pa35(9).output||pa34(9).output||pa33(9).output||pa32(9).output||pa31(9).output||pa30(9).output||pa29(9).output||pa28(9).output||pa27(9).output||pa26(9).output||pa25(9).output||pa24(9).output||
pa23(9).output||pa22(9).output||pa21(9).output||pa20(9).output||pa19(9).output||pa18(9).output||pa17(9).output||pa16(9).output|| pa15(9).output||pa14(9).output||pa13(9).output||pa12(9).output||pa11(9).output||pa10(9).output||pa9(9).output||pa8(9).output||pa7(9).output||pa6(9).output||pa5(9).output||
pa4(9).output||pa3(9).output||pa2(9).output||pa1(9).output)||rpad(nvl(pa81(9).output||pa82(9).output||pa83(9).output||pa84(9).output,' '),4,' ')||'| '||rpad(pa_stet(9).output,6,' ')||'           ' );
if pv_maxcpuprint = pa_stet(9).output then  fv_ta_obj(8) :=ty_obj( substr(fv_ta_obj(8).output,1,100)||'-MAX CPUs ['||pv_num_cpus||']-'||substr(fv_ta_obj(8).output,length('-MAX CPUs ['||pv_num_cpus||']-')+101  )); end if;

fv_ta_obj(9)  :=ty_obj(rpad(substr(pv_tmp_gcinfo(7).output,1,77),77,' ')||'  '||lpad(pa_stet(8).output,6,' ') ||' |'||(
pa80(8).output||pa79(8).output||pa78(8).output||pa77(8).output||pa76(8).output||pa75(8).output||pa74(8).output||pa73(8).output||pa72(8).output||pa71(8).output||pa70(8).output||pa69(8).output||pa68(8).output||pa67(8).output||pa66(8).output||pa65(8).output||pa64(8).output||pa63(8).output||pa62(8).output||
pa61(8).output||pa60(8).output||pa59(8).output||pa58(8).output||pa57(8).output||pa56(8).output||pa55(8).output||pa54(8).output||pa53(8).output||pa52(8).output||pa51(8).output||pa50(8).output||pa49(8).output||pa48(8).output||pa47(8).output||pa46(8).output||pa45(8).output||pa44(8).output||pa43(8).output||
pa42(8).output||pa41(8).output||pa40(8).output||pa39(8).output||pa38(8).output||pa37(8).output||pa36(8).output||pa35(8).output||pa34(8).output||pa33(8).output||pa32(8).output||pa31(8).output||pa30(8).output||pa29(8).output||pa28(8).output||pa27(8).output||pa26(8).output||pa25(8).output||pa24(8).output||
pa23(8).output||pa22(8).output||pa21(8).output||pa20(8).output||pa19(8).output||pa18(8).output||pa17(8).output||pa16(8).output||pa15(8).output||pa14(8).output||pa13(8).output||pa12(8).output||pa11(8).output||pa10(8).output||pa9(8).output||pa8(8).output||pa7(8).output||pa6(8).output||pa5(8).output||
pa4(8).output||pa3(8).output||pa2(8).output||pa1(8).output)||rpad(nvl(pa81(8).output||pa82(8).output||pa83(8).output||pa84(8).output,' '),4,' ')||'| '||rpad(pa_stet(8).output,6,' ')||'           ' );
if pv_maxcpuprint = pa_stet(8).output then  fv_ta_obj(9) :=ty_obj( substr(fv_ta_obj(9).output,1,100)||'-MAX CPUs ['||pv_num_cpus||']-'||substr(fv_ta_obj(9).output,length('-MAX CPUs ['||pv_num_cpus||']-')+101  )); end if;

fv_ta_obj(10)  :=ty_obj(rpad(substr(pv_tmp_gcinfo(8).output,1,77),77,' ')||'  '||lpad(pa_stet(7).output,6,' ') ||' |'||(
pa80(7).output||pa79(7).output||pa78(7).output||pa77(7).output||pa76(7).output||pa75(7).output||pa74(7).output||pa73(7).output||pa72(7).output||pa71(7).output||pa70(7).output||pa69(7).output||pa68(7).output||pa67(7).output||pa66(7).output||pa65(7).output||pa64(7).output||pa63(7).output||pa62(7).output||
pa61(7).output||pa60(7).output||pa59(7).output||pa58(7).output||pa57(7).output||pa56(7).output||pa55(7).output||pa54(7).output||pa53(7).output||pa52(7).output||pa51(7).output||pa50(7).output||pa49(7).output||pa48(7).output||pa47(7).output||pa46(7).output||pa45(7).output||pa44(7).output||pa43(7).output||
pa42(7).output||pa41(7).output||pa40(7).output||pa39(7).output||pa38(7).output||pa37(7).output||pa36(7).output||pa35(7).output||pa34(7).output||pa33(7).output||pa32(7).output||pa31(7).output||pa30(7).output||pa29(7).output||pa28(7).output||pa27(7).output||pa26(7).output||pa25(7).output||pa24(7).output||
pa23(7).output||pa22(7).output||pa21(7).output||pa20(7).output||pa19(7).output||pa18(7).output||pa17(7).output||pa16(7).output||pa15(7).output||pa14(7).output||pa13(7).output||pa12(7).output||pa11(7).output||pa10(7).output||pa9(7).output||pa8(7).output||pa7(7).output||pa6(7).output||pa5(7).output||
pa4(7).output||pa3(7).output||pa2(7).output||pa1(7).output)||rpad(nvl(pa81(7).output||pa82(7).output||pa83(7).output||pa84(7).output,' '),4,' ')||'| '||rpad(pa_stet(7).output,6,' ')||'           ' );
if pv_maxcpuprint = pa_stet(7).output then  fv_ta_obj(10) :=ty_obj( substr(fv_ta_obj(10).output,1,100)||'-MAX CPUs ['||pv_num_cpus||']-'||substr(fv_ta_obj(10).output,length('-MAX CPUs ['||pv_num_cpus||']-')+101  )); end if;

fv_ta_obj(11) :=ty_obj(rpad(substr(pv_tmp_gcinfo(9).output,1,77),77,' ')||'  '||lpad(pa_stet(6).output,6,' ') ||' |'||(
pa80(6).output||pa79(6).output||pa78(6).output||pa77(6).output||pa76(6).output||pa75(6).output||pa74(6).output||pa73(6).output||pa72(6).output||pa71(6).output||pa70(6).output||pa69(6).output||pa68(6).output||pa67(6).output||pa66(6).output||pa65(6).output||pa64(6).output||pa63(6).output||pa62(6).output||
pa61(6).output||pa60(6).output||pa59(6).output||pa58(6).output||pa57(6).output||pa56(6).output||pa55(6).output||pa54(6).output||pa53(6).output||pa52(6).output||pa51(6).output||pa50(6).output||pa49(6).output||pa48(6).output||pa47(6).output||pa46(6).output||pa45(6).output||pa44(6).output||pa43(6).output||
pa42(6).output||pa41(6).output||pa40(6).output||pa39(6).output||pa38(6).output||pa37(6).output||pa36(6).output||pa35(6).output||pa34(6).output||pa33(6).output||pa32(6).output||pa31(6).output||pa30(6).output||pa29(6).output||pa28(6).output||pa27(6).output||pa26(6).output||pa25(6).output||pa24(6).output||
pa23(6).output||pa22(6).output||pa21(6).output||pa20(6).output||pa19(6).output||pa18(6).output||pa17(6).output||pa16(6).output||pa15(6).output||pa14(6).output||pa13(6).output||pa12(6).output||pa11(6).output||pa10(6).output||pa9(6).output||pa8(6).output||pa7(6).output||pa6(6).output||pa5(6).output||
pa4(6).output||pa3(6).output||pa2(6).output||pa1(6).output)||rpad(nvl(pa81(6).output||pa82(6).output||pa83(6).output||pa84(6).output,' '),4,' ')||'| '||rpad(pa_stet(6).output,6,' ')||'           ' );
if pv_maxcpuprint = pa_stet(6).output then  fv_ta_obj(11) :=ty_obj( substr(fv_ta_obj(11).output,1,100)||'-MAX CPUs ['||pv_num_cpus||']-'||substr(fv_ta_obj(11).output,length('-MAX CPUs ['||pv_num_cpus||']-')+101  )); end if;


fv_ta_obj(12) :=ty_obj(rpad(substr(pv_tmp_gcinfo(10).output,1,77),77,' ')||'  '||lpad(pa_stet(5).output,6,' ') ||' |'||(
pa80(5).output||pa79(5).output||pa78(5).output||pa77(5).output||pa76(5).output||pa75(5).output||pa74(5).output||pa73(5).output||pa72(5).output||pa71(5).output||pa70(5).output||pa69(5).output||pa68(5).output||pa67(5).output||pa66(5).output||pa65(5).output||pa64(5).output||pa63(5).output||pa62(5).output||
pa61(5).output||pa60(5).output||pa59(5).output||pa58(5).output||pa57(5).output||pa56(5).output||pa55(5).output||pa54(5).output||pa53(5).output||pa52(5).output||pa51(5).output||pa50(5).output||pa49(5).output||pa48(5).output||pa47(5).output||pa46(5).output||pa45(5).output||pa44(5).output||pa43(5).output||
pa42(5).output||pa41(5).output||pa40(5).output||pa39(5).output||pa38(5).output||pa37(5).output||pa36(5).output||pa35(5).output||pa34(5).output||pa33(5).output||pa32(5).output||pa31(5).output||pa30(5).output||pa29(5).output||pa28(5).output||pa27(5).output||pa26(5).output||pa25(5).output||pa24(5).output||
pa23(5).output||pa22(5).output||pa21(5).output||pa20(5).output||pa19(5).output||pa18(5).output||pa17(5).output||pa16(5).output||pa15(5).output||pa14(5).output||pa13(5).output||pa12(5).output||pa11(5).output||pa10(5).output||pa9(5).output||pa8(5).output||pa7(5).output||pa6(5).output||pa5(5).output||
pa4(5).output||pa3(5).output||pa2(5).output||pa1(5).output)||rpad(nvl(pa81(5).output||pa82(5).output||pa83(5).output||pa84(5).output,' '),4,' ')||'| '||rpad(pa_stet(5).output,6,' ')||'           ' );
if pv_maxcpuprint = pa_stet(5).output then  fv_ta_obj(12) :=ty_obj( substr(fv_ta_obj(12).output,1,100)||'-MAX CPUs ['||pv_num_cpus||']-'||substr(fv_ta_obj(12).output,length('-MAX CPUs ['||pv_num_cpus||']-')+101  )); end if;



fv_ta_obj(13) :=ty_obj(rpad(substr(pv_tmp_gcinfo(11).output,1,77),77,' ')||'  '||lpad(pa_stet(4).output,6,' ') ||' |'||(
pa80(4).output||pa79(4).output||pa78(4).output||pa77(4).output||pa76(4).output||pa75(4).output||pa74(4).output||pa73(4).output||pa72(4).output||pa71(4).output||pa70(4).output||pa69(4).output||pa68(4).output||pa67(4).output||pa66(4).output||pa65(4).output||pa64(4).output||pa63(4).output||pa62(4).output||
pa61(4).output||pa60(4).output||pa59(4).output||pa58(4).output||pa57(4).output||pa56(4).output||pa55(4).output||pa54(4).output||pa53(4).output||pa52(4).output||pa51(4).output||pa50(4).output||pa49(4).output||pa48(4).output||pa47(4).output||pa46(4).output||pa45(4).output||pa44(4).output||pa43(4).output||
pa42(4).output||pa41(4).output||pa40(4).output||pa39(4).output||pa38(4).output||pa37(4).output||pa36(4).output||pa35(4).output||pa34(4).output||pa33(4).output||pa32(4).output||pa31(4).output||pa30(4).output||pa29(4).output||pa28(4).output||pa27(4).output||pa26(4).output||pa25(4).output||pa24(4).output||
pa23(4).output||pa22(4).output||pa21(4).output||pa20(4).output||pa19(4).output||pa18(4).output||pa17(4).output||pa16(4).output||pa15(4).output||pa14(4).output||pa13(4).output||pa12(4).output||pa11(4).output||pa10(4).output||pa9(4).output||pa8(4).output||pa7(4).output||pa6(4).output||pa5(4).output||
pa4(4).output||pa3(4).output||pa2(4).output||pa1(4).output)||rpad(nvl(pa81(4).output||pa82(4).output||pa83(4).output||pa84(4).output,' '),4,' ')||'| '||rpad(pa_stet(4).output,6,' ')||'           ' );
if pv_maxcpuprint = pa_stet(4).output then  fv_ta_obj(13) :=ty_obj( substr(fv_ta_obj(13).output,1,100)||'-MAX CPUs ['||pv_num_cpus||']-'||substr(fv_ta_obj(13).output,length('-MAX CPUs ['||pv_num_cpus||']-')+101  )); end if;


fv_ta_obj(14) :=ty_obj(rpad(substr(pv_tmp_gcinfo(12).output,1,55),55,' ')||'            OTHER : '||pv_oth_dig ||'   '||lpad(pa_stet(3).output,6,' ') ||' |'||(
pa80(3).output||pa79(3).output||pa78(3).output||pa77(3).output||pa76(3).output||pa75(3).output||pa74(3).output||pa73(3).output||pa72(3).output||pa71(3).output||pa70(3).output||pa69(3).output||pa68(3).output||pa67(3).output||pa66(3).output||pa65(3).output||pa64(3).output||pa63(3).output||pa62(3).output||
pa61(3).output||pa60(3).output||pa59(3).output||pa58(3).output||pa57(3).output||pa56(3).output||pa55(3).output||pa54(3).output||pa53(3).output||pa52(3).output||pa51(3).output||pa50(3).output||pa49(3).output||pa48(3).output||pa47(3).output||pa46(3).output||pa45(3).output||pa44(3).output||pa43(3).output||
pa42(3).output||pa41(3).output||pa40(3).output||pa39(3).output||pa38(3).output||pa37(3).output||pa36(3).output||pa35(3).output||pa34(3).output||pa33(3).output||pa32(3).output||pa31(3).output||pa30(3).output||pa29(3).output||pa28(3).output||pa27(3).output||pa26(3).output||pa25(3).output||pa24(3).output||
pa23(3).output||pa22(3).output||pa21(3).output||pa20(3).output||pa19(3).output||pa18(3).output||pa17(3).output||pa16(3).output||pa15(3).output||pa14(3).output||pa13(3).output||pa12(3).output||pa11(3).output||pa10(3).output||pa9(3).output||pa8(3).output||pa7(3).output||pa6(3).output||pa5(3).output||
pa4(3).output||pa3(3).output||pa2(3).output||pa1(3).output)||rpad(nvl(pa81(3).output||pa82(3).output||pa83(3).output||pa84(3).output,' '),4,' ')||'| '||rpad(pa_stet(3).output,6,' ')||'           ');
if pv_maxcpuprint = pa_stet(3).output then  fv_ta_obj(14) :=ty_obj( substr(fv_ta_obj(14).output,1,100)||'-MAX CPUs ['||pv_num_cpus||']-'||substr(fv_ta_obj(14).output,length('-MAX CPUs ['||pv_num_cpus||']-')+101  )); end if;


fv_ta_obj(15) :=ty_obj(rpad(substr(pv_tmp_gcinfo(13).output,1,55),55,' ')||'          CLUSTER : '||pv_clu_dig ||'   '||lpad(pa_stet(2).output,6,' ') ||' |'||(
pa80(2).output||pa79(2).output||pa78(2).output||pa77(2).output||pa76(2).output||pa75(2).output||pa74(2).output||pa73(2).output||pa72(2).output||pa71(2).output||pa70(2).output||pa69(2).output||pa68(2).output||pa67(2).output||pa66(2).output||pa65(2).output||pa64(2).output||pa63(2).output||pa62(2).output||
pa61(2).output||pa60(2).output||pa59(2).output||pa58(2).output||pa57(2).output||pa56(2).output||pa55(2).output||pa54(2).output||pa53(2).output||pa52(2).output||pa51(2).output||pa50(2).output||pa49(2).output||pa48(2).output||pa47(2).output||pa46(2).output||pa45(2).output||pa44(2).output||pa43(2).output||
pa42(2).output||pa41(2).output||pa40(2).output||pa39(2).output||pa38(2).output||pa37(2).output||pa36(2).output||pa35(2).output||pa34(2).output||pa33(2).output||pa32(2).output||pa31(2).output||pa30(2).output||pa29(2).output||pa28(2).output||pa27(2).output||pa26(2).output||pa25(2).output||pa24(2).output||
pa23(2).output||pa22(2).output||pa21(2).output||pa20(2).output||pa19(2).output||pa18(2).output||pa17(2).output||pa16(2).output||pa15(2).output||pa14(2).output||pa13(2).output||pa12(2).output||pa11(2).output||pa10(2).output||pa9(2).output||pa8(2).output||pa7(2).output||pa6(2).output||pa5(2).output||
pa4(2).output||pa3(2).output||pa2(2).output||pa1(2).output)||rpad(nvl(pa81(2).output||pa82(2).output||pa83(2).output||pa84(2).output,' '),4,' ')||'| '||rpad(pa_stet(2).output,6,' ')||'           ' );
if pv_maxcpuprint = pa_stet(2).output then  fv_ta_obj(15) :=ty_obj( substr(fv_ta_obj(15).output,1,100)||'-MAX CPUs ['||pv_num_cpus||']-'||substr(fv_ta_obj(15).output,length('-MAX CPUs ['||pv_num_cpus||']-')+101  )); end if;


fv_ta_obj(16) :=ty_obj(rpad(substr(pv_tmp_gcinfo(14).output,1,55),55,' ')||'               IO : '||pv_io_dig ||'   '||lpad(pa_stet(1).output,6,' ') ||' |'||(
pa80(1).output||pa79(1).output||pa78(1).output||pa77(1).output||pa76(1).output||pa75(1).output||pa74(1).output||pa73(1).output||pa72(1).output||pa71(1).output||pa70(1).output||pa69(1).output||pa68(1).output||pa67(1).output||pa66(1).output||pa65(1).output||pa64(1).output||pa63(1).output||pa62(1).output||
pa61(1).output||pa60(1).output||pa59(1).output||pa58(1).output||pa57(1).output||pa56(1).output||pa55(1).output||pa54(1).output||pa53(1).output||pa52(1).output||pa51(1).output||pa50(1).output||pa49(1).output||pa48(1).output||pa47(1).output||pa46(1).output||pa45(1).output||pa44(1).output||pa43(1).output||
pa42(1).output||pa41(1).output||pa40(1).output||pa39(1).output||pa38(1).output||pa37(1).output||pa36(1).output||pa35(1).output||pa34(1).output||pa33(1).output||pa32(1).output||pa31(1).output||pa30(1).output||pa29(1).output||pa28(1).output||pa27(1).output||pa26(1).output||pa25(1).output||pa24(1).output||
pa23(1).output||pa22(1).output||pa21(1).output||pa20(1).output||pa19(1).output||pa18(1).output||pa17(1).output||pa16(1).output||pa15(1).output||pa14(1).output||pa13(1).output||pa12(1).output||pa11(1).output||pa10(1).output||pa9(1).output||pa8(1).output||pa7(1).output||pa6(1).output||pa5(1).output||
pa4(1).output||pa3(1).output||pa2(1).output||pa1(1).output)||rpad(nvl(pa81(1).output||pa82(1).output||pa83(1).output||pa84(1).output,' '),4,' ')||'| '||rpad(pa_stet(1).output,6,' ')||'           ' );
if pv_maxcpuprint = pa_stet(1).output then  fv_ta_obj(16) :=ty_obj( substr(fv_ta_obj(16).output,1,100)||'-MAX CPUs ['||pv_num_cpus||']-'||substr(fv_ta_obj(16).output,length('-MAX CPUs ['||pv_num_cpus||']-')+101  )); end if;

fv_ta_obj(17) :=ty_obj(rpad(' ',55,' ')||'Legend -      CPU : '||pv_cpu_dig ||'   '||lpad(0,6,' ')||' +'||rpad('-',84,'-')||'+ 0');

fv_ta_obj(18) :=ty_obj(rpad(' ',71,' ')||'        '||lpad(' ',8,' ')||'^'||' '||to_char(   sysdate-(1/24/60/(60/(p_sample*80)))     ,'hh24:mi:ss')||lpad(' ',21,' ')||to_char(sysdate-(1/24/60/(60/(p_sample*40))),'hh24:mi:ss')||' '||'^'||lpad(' ',29,' ')||to_char(sysdate,'hh24:mi:ss')||' '||'^');

return fv_ta_obj;
exception
when others then
raise_application_Error(-20001,'GACTSESSRET : '||sqlerrm );
end;
-------------------/



------##################
-- gsqlm : ---  building dataset from gv$sql_monitor for all running queries.
--- print info for pv_top_sql
------##################
function gsqlm  return ta_obj
as
fv_Ta_obj     ta_obj  := ta_obj();

v_rcnt        int := 0 ;
fv_sql        varchar2(500) := q'[ select ty_gsqlm(inst_id,sql_id,substr(sql_text,1,100),elapsed_time,cpu_time,concurrency_wait_time,
                                                    cluster_wait_Time,user_io_wait_time,physical_read_bytes,px_server#)
                                    from gv$sql_monitor where status = 'EXECUTING' and elapsed_time > 0
                                  ]';


----##
function  f_convert_datetime(fvs number ) return varchar2
as
v_result    varchar2(20) ;
begin
with hrs as (
  select secs, trunc(secs / 60 / 60) as h
    from ( select fvs secs from dual )
    )
 , mins as (
  select secs, h, trunc((secs - h * 60 * 60) / 60) as m
    from hrs
         )
select lpad(h,2,'0')||':'||lpad(m,2,'0')||':'||lpad((secs - (h * 60 * 60) - (m * 60) ),2,'0') into  v_result
  from  mins;
  
  v_result := replace(v_result,'::') ;
  
return v_result;
end;
---##

begin
execute immediate fv_sql bulk collect into pv_only_gsqlm;

fv_ta_obj.extend;fv_ta_obj(fv_ta_obj.count) := ty_obj( ' ');
fv_ta_obj.extend;fv_ta_obj(fv_ta_obj.count) := ty_obj( '+--SqlID--------+--SqlText---'||lpad('-',73,'-')||'+-LongstDur-+-InstCnt-+-Cnt-+--CPU%--+--CONC%--+--CLUS%--+-IO%-+-PhyReadMb+'  );


for i in (      select (
		       select  round(max(elapsed_time)/1000000)  from table(pv_only_gsqlm) gsq1 where
		       gsq1.sql_id = gsm.sql_id
	              ) maxduration,
                     (select count(distinct inst_id) from table(pv_only_gash)  sq1 where sq1.sql_id = gsm.sql_id) acrossins,
                             sql_id,
                            ( select substr(sql_text,1,87) from table(pv_only_gash) sq2 where sq2.sql_id = gsm.sql_id and rownum = 1) sql_text,
                            ( select lpad(nvl(round(sum(cpu_time)/ nvl(sum(elapsed_time),1) *100,1),0),6,' ')||' | '||lpad(nvl(round(sum(concurrency_Wait_Time)/nvl(sum(elapsed_time),1)*100,1),0),6,' ') ||'  | '||
                                     lpad(nvl(round(sum(cluster_Wait_Time)/nvl(sum(elapsed_time),1)*100,1),0),6,' ')||'  | '||lpad(nvl(round(sum(user_io_wait_time)/nvl(sum(elapsed_time),1)*100,1),0),4,' ')||'|'||lpad(nvl(round(sum(physical_read_bytes)/1048576),0),10,' ')||'|'
                                     from table(pv_only_gsqlm) sql3 where sql3.sql_id = gsm.sql_id  ) db_time,
                                        ( select count( distinct inst_id||sid) from table(pv_only_gash) sq4 where sq4.sql_id = gsm.sql_id ) exccount
                                          from  ( select  distinct output sql_id from table(pv_top_sql)) gsm
         ) loop


 v_rcnt := 1;
 fv_ta_obj.extend;

fv_ta_obj(fv_ta_obj.count) := ty_obj('| '||i.sql_id||' | '||rpad(nvl(i.sql_text,' '),83,' ')||' | '||lpad(nvl(f_convert_datetime(i.maxduration),' '),9,' ')||' |    '|| rpad(i.acrossins,4,' ')||' |  '||lpad(i.exccount,2,' ')||' | '||i.db_time );
fv_ta_obj.extend;fv_ta_obj(fv_ta_obj.count) := ty_obj( '+---------------+'||lpad('-',85,'-')||'+-----------+---------+-----+--------+---------+---------+-----+----------+'  );

        end loop;


           if v_rcnt = 0 then
            fv_ta_obj.extend;fv_ta_obj(fv_ta_obj.count) := ty_obj( '+---------------+'||lpad('-',85,'-')||'+-----------+---------+-----+--------+---------+---------+-----+----------+'  );
           end if;

return  fv_ta_obj;
exception
when others then
raise_application_Error(-20001,'GSQLM : '||sqlerrm  );
end;
-------------------/



------##################
-- gtop : pipe lined function, which calls all the sections
------##################

FUNCTION gtop( pv_arr_size int default 47 , pv_sample  int default 6) RETURN ta_obj pipelined
is
v_tot_rec       int := 0 ;
BEGIN
p_sample  := pv_Sample;

      --- Printing Banner..
        begin
        pipe row ( ty_obj('########################################')); v_tot_rec := v_tot_Rec + 1;
        pipe row ( ty_obj('Taking first sample .......             ')); v_tot_rec := v_tot_Rec + 1;
        pipe row ( ty_obj('Author : Jagjeet Singh                 ')); v_tot_rec := v_tot_Rec + 1;
        pipe row ( ty_obj('########################################')); v_tot_rec := v_tot_Rec + 1;
           if v_tot_rec <= pv_arr_size then
                     for i in 1..(pv_arr_size-v_tot_rec) loop
                     pipe row ( ty_obj(' ')); v_tot_rec := v_tot_Rec + 1;
                    end loop;
           end if;

        initactarr;                 -- calling initactarr to extend all the arrays
        pv_first_ginst := ginsteff; -- getting first sample for ginsteff
        dbms_lock.sleep(pv_sample); -- sleep based on passed parameter, default is 6 seconds
        v_tot_rec := 0;

        end;

loop

--#######################
-- Printing Instance Eff.
--#######################
------------------ -- Building output for Inst Eff.
pv_last_ginst :=  ginsteff;  -- Taking second sample for Inst Eff. data
pv_tmp_obj    :=  ginstbuilddata(pv_first_ginst,pv_last_ginst);  -- getting data formatted
for i in 1..pv_tmp_obj.count loop   pipe row( ty_obj( pv_tmp_obj(i).output )); v_tot_rec := v_tot_rec + 1; end loop;  pipe row ( ty_obj(' ')); v_tot_rec := v_tot_rec + 1; -- printing
pv_tmp_obj.delete;  -- deleting temp obj
------------------


--#########################
-- Printing TOP SQLs,Waits
--#########################

------------------
pv_only_gash  := gash(pv_st_sample,pv_et_sample); -- building dataset from global active session history
pv_tmp_obj    := gashbuilddata (pv_only_gash);    -- getting dataset formatted
for i in 1..pv_tmp_obj.count loop   pipe row( ty_obj( pv_tmp_obj(i).output )); v_tot_rec := v_tot_rec + 1; end loop;  -- printing
pv_tmp_obj.delete;  -- deleting temp obj
------------------




--#########################
-- Building Cluster/GC* data
--#########################
pv_tmp_gcinfo :=  gcinfo ;    -- building dataset for Cluster waits,



--#########################
-- Printing Active Sessions
--#########################
-----------------
gactses ;
pv_tmp_obj := gactsessret;
for i in 1..pv_tmp_obj.count loop   pipe row( ty_obj( pv_tmp_obj(i).output )); v_tot_rec := v_tot_rec + 1; end loop;  pipe row ( ty_obj(' ')); v_tot_rec := v_tot_rec + 1;
pv_tmp_obj.delete;
--------------------

--#########################
-- Printing SQL Monitor
--#########################
------------------
pv_tmp_obj := gsqlm;    -- using pv_top_sql to fill detail from sql monitor
for i in 1..pv_tmp_obj.count loop   pipe row( ty_obj( pv_tmp_obj(i).output )); v_tot_rec := v_tot_rec + 1; end loop;
pv_tmp_obj.delete;
-------------------


--#######################
-- Fill remaining Array
--#######################
        if v_tot_rec < pv_arr_size then
            for i in 1..(pv_arr_size-v_tot_rec) loop
             pipe row ( ty_obj(' '));
            end loop;
        end if;
--##############################
-- Sleep, triming all the arrays
--
--##############################
pv_first_ginst := pv_last_ginst;   -- shuffling ginst collection
dbms_lock.sleep(pv_sample);
v_tot_rec := 0;

end loop ;
return ;
exception
when others then
raise_application_Error(-20001,'GTOP: '||sqlerrm );
end;
---
--########################
-- Package Begin Section
--########################
Begin
dbms_application_info.set_action('JSS.GTOP');
select value  into pv_block_size from v$parameter where name = 'db_block_size' ;   -- this query will get executed once per session
END jss;
/
