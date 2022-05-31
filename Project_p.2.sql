/*
Из источника
http://xn----ctbjnaatncev9av3a8f8b.xn--p1ai/%D1%82%D0%B0%D0%B1%D0%BB%D0%B8%D1%86%D0%B0_%D0%B8%D0%BD%D1%84%D0%BB%D1%8F%D1%86%D0%B8%D0%B8.aspx
загружены данные о ежемесячной инфляции в таблицу:

create table student00.ST_INFLATION
(
  currcode VARCHAR2(10),
  dt       DATE,
  coeff    NUMBER
);
create table student00.mcftr(f1 varchar2(100), f2 varchar2(100));

Из источника
https://investfunds.ru/indexes/18085/
загружены данные об изменении индекса полной доходности Мосбиржи MCFTR в таблицу

*/

create or replace function student00.st_get_inf_period(in_currcode varchar2,
                                             dt_begin    date,
                                             dt_end      date)
  return number as
  v_inf_period number;
begin
  if dt_begin > dt_end then
    raise_application_error(-20001, 'dt_begin > dt_end?!');
  elsif dt_begin < to_date('01.01.1991', 'dd.mm.yyyy') then
    raise_application_error(-20001, 'dt_begin < 01-01-1991?!');
  end if;
  with calendar as
   (select add_months(trunc(dt_begin, 'mon'), level - 1) dt
      from dual
    connect by level < months_between(dt_end, dt_begin) + 2),
  dat as
   (select calendar.dt, 1 + t.coeff / 100 coeff
      from calendar
      left join st_inflation t
        on calendar.dt = t.dt
       and t.currcode = in_currcode)
  select exp(sum(ln(case
                      when trunc(dt_begin, 'mon') = dt and
                           months_between(dt_end, dt) < 1 then
                       power(coeff, (dt_end - dt_begin) / (last_day(dt) - dt + 1))
                      when trunc(dt_begin, 'mon') = dt then
                       power(coeff,
                             (last_day(dt) - dt_begin + 1) / (last_day(dt) - dt + 1))
                      when months_between(dt_end, dt) < 1 then
                       power(coeff, (dt_end - dt) / (last_day(dt) - dt + 1))
                      else
                       coeff
                    end)))
    into v_inf_period
    from dat
   where dt >= trunc(dt_begin, 'mon')
     and dt < dt_end;
  return nvl(v_inf_period, 1);
end st_get_inf_period;

--запрос, демонстрирующий доходность вложений 
--в индекс MCFTR (с учётом инфляции, в современных ценах) за каждый из 12 последних лет

--ср.рост за каждый из последних num_years годов по MCFTR
;
with const as
 (select num_years, add_months(end_dt, -12 * num_years) start_dt, end_dt
    from (select 13 num_years, to_date('01.01.2022', 'dd.mm.yyyy') end_dt
            from dual)),
cld as
 (select end_dt - level + 1 dt,
         student00.st_get_inf_period('RUB', end_dt - level + 1, end_dt) coeff_infl
    from const
  connect by level <= end_dt - start_dt + 1),
m as
 (select to_date(f1, 'dd.mm.yyyy') dt,
         to_number(f2, '99999999999999999999D99999999999999999999', 'NLS_NUMERIC_CHARACTERS='', ''') mcftr
    from student00.mcftr),
i as
 (select cld.dt,
         last_value(m.mcftr ignore nulls) over(order by cld.dt) mcftr,
         round(last_value(m.mcftr ignore nulls) over(order by cld.dt) * cld.coeff_infl, 2) mcftr_with_infl
    from cld
    left join m
      on cld.dt = m.dt
   order by cld.dt),
pre as
 (select /*+ materialize*/
   t.num_year, t.start_dt, t.end_dt,
   min(i.dt) min_dt,
   max(i.mcftr_with_infl) keep(dense_rank first order by i.dt) start_mcftr_with_infl,
   max(i.mcftr_with_infl) keep(dense_rank last order by i.dt) end_mcftr_with_infl
    from i,
         (select level num_year,
                 add_months(end_dt, -12 * level) start_dt,
                 add_months(end_dt, -12 * (level - 1)) end_dt
            from const
          connect by level <= num_years) t
   where i.dt between t.start_dt and t.end_dt and num_year <= 12
   group by t.num_year, t.start_dt, t.end_dt)
select num_year, (to_char (start_dt, 'DD.MM.YYYY')) as Начало, (to_char (end_dt, 'DD.MM.YYYY')) as Конец, --start_mcftr_with_infl, end_mcftr_with_infl,
       round(avg(end_mcftr_with_infl / start_mcftr_with_infl), 6) as Коэфф_роста_с_учётом_инфляции
  from pre
 where min_dt = start_dt
 group by num_year, start_dt, end_dt, start_mcftr_with_infl, end_mcftr_with_infl
 order by num_year;

 
