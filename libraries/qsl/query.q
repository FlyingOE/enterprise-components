/L/ Copyright (c) 2011-2014 Exxeleron GmbH
/L/
/L/ Licensed under the Apache License, Version 2.0 (the "License");
/L/ you may not use this file except in compliance with the License.
/L/ You may obtain a copy of the License at
/L/
/L/   http://www.apache.org/licenses/LICENSE-2.0
/L/
/L/ Unless required by applicable law or agreed to in writing, software
/L/ distributed under the License is distributed on an "AS IS" BASIS,
/L/ WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
/L/ See the License for the specific language governing permissions and
/L/ limitations under the License.

/A/ DEVnet:  Pawel Hudak
/V/ 3.0

/S/ Query library:
/S/ Simple library for executing functional query over hdb and rdb servers in one call.

/------------------------------------------------------------------------------/
/                           interface functions                                /
/------------------------------------------------------------------------------/

/F/ Retrieve data from rdb/hdb servers as single functional query. 
/F/ If the daysRange includes both rdb and hdb dates, then query will be executed on both rdb and hdb, and the result will be joined.
/F/ Notes:
/F/ - date column will be always added to the result
/F/ - if query on one of the source servers fails, function will generate signal with error source and information

/E/ ---------------------------------------------------------------------------
/E/ // Query for last bid and last ask grouped by sym column for range (2013.10.02;2010.12.03).
/E/ q).query.data[`core.rdb`core.hdb;`quote;();(2013.10.02;2010.12.03);enlist[`sym]!enlist[`sym];`lastBid`lastAsk!("last bid";"last ask")]
/E/ date       sym    | lastBid lastAsk
/E/ ------------------| ---------------
/E/ 2013.10.02 instr11| 37.56   20.90  
/E/ 2013.10.02 instr12| 28.87   9.82  
/E/ 2013.10.02 instr13| 44.92   76.56  
/E/ 2013.10.02 instr14| 61.86   28.12  
/E/ 2013.10.03 instr11| 37.56   20.23  
/E/ 2013.10.03 instr12| 28.88   9.83   
/E/ 2013.10.03 instr13| 44.32   76.58
/E/ 2013.10.03 instr14| 62.86   26.22
/E/ 
/E/ ---------------------------------------------------------------------------
/E/ // Query for sym, bid and ask columns for rows with sym=`instr11, for yesterday and today.
/E/ // Note that condition is specified as list of expression trees
/E/ q).query.data[`core.rdb`core.hdb;`quote;enlist (=;`sym;enlist `instr11);(.z.d-1;.z.d);0b;`sym`bid`ask!("sym";"bid";"ask")]
/E/ date       sym     bid   ask  
/E/ ------------------------------
/E/ 2013.10.22 instr11 37.56 20.93
/E/ 2013.10.22 instr11 37.57 20.93
/E/ 2013.10.22 instr11 37.57 20.92
/E/ 2013.10.22 instr11 37.57 20.91
/E/ 2013.10.22 instr11 37.56 20.91
/E/ 2013.10.22 instr11 37.56 20.93
/E/ 2013.10.22 instr11 37.56 20.93
/E/ 2013.10.23 instr11 37.58 20.93
/E/ 2013.10.23 instr11 37.58 20.92
/E/ 2013.10.23 instr11 37.56 20.92
/E/ 2013.10.23 instr11 37.56 20.91
/E/
/E/ ---------------------------------------------------------------------------
/E/ // Query for all columns for rows with sym=`instr11 and time within range 23:25 23:30 for today.
/E/ // Note that condition is specified as list of strings.
/E/ q).query.data[`core.rdb`core.hdb;`quote;("sym=`instr11";"time within 23:25 23:30");(.z.d);0b;()]
/E/ date       time         sym     bid   ask   bidSize askSize
/E/ -----------------------------------------------------------
/E/ 2013.12.13 23:25:00.000 instr11 37.56 20.93 668     4443   
/E/ 2013.12.13 23:26:00.000 instr11 37.56 20.93 668     4443   
/E/ 2013.12.13 23:27:00.000 instr11 37.56 20.93 668     4443   
/E/ 2013.12.13 23:28:00.000 instr11 37.56 20.93 668     4443   
/E/ 2013.12.13 23:29:00.000 instr11 37.56 20.93 668     4443   
/E/ 2013.12.13 23:30:00.000 instr11 37.56 20.93 668     4443
/E/ ---------------------------------------------------------------------------

/P/ servers:PAIR[SYMBOL]   - list of two symbols containing rdb and hdb server names; *note:* both must be provided in given order
/P/ tab:SYMBOL             - table name
/P/ cond:LIST<STRING|LIST> - list of conditions in a form of parse tree or strings, empty list in case there is no condition; *note:* date condition will be added automatically according to daysRange parameter
/P/ daysRange:LIST<DATE>   - day, or range of days (pair of two dates)
/P/ gr:DICT                - dictionary for grouping condition, or 0b
/P/ col:DICT               - dictionary with column->result content
/R/ The result is a merge of hdb and rdb results; *note:* the date column will be added to the result
.query.data:{[servers;tab;cond;daysRange;gr;col]
  range:$[1=count daysRange;(daysRange;daysRange);asc daysRange];
  cond[p]:parse each cond p:where 10=type each cond;
  col[p]:parse each col p:where 10=type each col;
  res:();
  if[.sl.eodSyncedDate[] within range;
    q:(?;tab;enlist cond;gr;col);
    r:.pe.dot[{[h;q]h(eval;q)};(.hnd.h[servers 0];q);{(`signal;x)}];
    if[`signal~first r;'"rdb[",.Q.s1[servers 0],"] signals '[",r[1],"] after query: ",.Q.s1[q]];
    res,:$[not 0b~gr;1+count gr;0]!(`date,key gr) xcols update date:.sl.eodSyncedDate[] from 0!r;
    ];
  if[range[0]<.sl.eodSyncedDate[];
    cond:enlist[enlist[(within;`date;range)]],'enlist cond;
    $[0b~gr; 
      if[(not `date in col) and count col;col:(enlist[`date]!enlist[`date]),col];
      gr:(enlist[`date]!enlist[`date]),gr
      ];
    q:(?;tab;cond;gr;col);
    r:.pe.dot[{[h;q]h(eval;q)};(.hnd.h[servers 1];q);{(`signal;x)}];
    if[`signal~first r;'"hdb[",.Q.s1[servers 1],"] signals '[",r[1],"] after query: ",.Q.s1[q]];
    res,:.hnd.h[servers 1](eval;q);
    ];
  `date xasc res
  };

/------------------------------------------------------------------------------/
