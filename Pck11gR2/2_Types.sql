REM drop type ta_obj;
REM drop type ta_ginst;
REM drop type ta_gash;
REM drop type ta_gc;
REM drop type ta_gsqlm;

REM drop type ty_obj;
REM drop type ty_ginst;
REM drop type ty_gash;
REM drop type ty_gsqlm;
REM drop type ty_gc;

create or replace
type ty_obj as object
      (
       output varchar2(250)
      );
/

create or replace
type ty_ginst as object
  (
        inst_id       number(2),
        inst_name     varchar2(16),
        statname      varchar2(64),
        value         number,
        Times         date
  );
/

create or replace
type ty_gash as object (
   inst_id    number,
   sid        number,
   sql_id     varchar2(13),
   sql_child  number,
   sql_text   varchar2(100),
   sql_op     varchar2(64),
   event      varchar2(64),
   wait_class varchar2(64),
   time_Waited number,
   obj#        number
   ) ;
/

create or replace type ty_gsqlm as object (
  inst_id                    number,
  sql_id                     varchar2(13),
  sql_text                   varchar2(100),
  elapsed_time               number,
  cpu_time                   number,
  concurrency_Wait_time      number,
  cluster_Wait_time          number,
  user_io_wait_time          number,
  physical_read_bytes        number,
  px_server#                 number
  );
 /

create or replace type ty_gc as object
 (
  inst_id    number(2),
  GCBCS      number,
  GCBRS      number,
  GMSR      number
);
/

create or replace type ta_gc as table of ty_gc;
/


create or replace type ta_gsqlm is table of ty_gsqlm;
/

create or replace
type ta_obj as table of ty_obj;
/

create or replace
type ta_ginst as table of ty_ginst;
/

create or replace
type ta_gash as table of ty_gash;
/
