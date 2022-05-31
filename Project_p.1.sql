create or replace function mg_to_number(s in varchar2) return number as
begin
  return to_number(s, '9999D99', 'NLS_NUMERIC_CHARACTERS=''. ''');
exception
  when others then
    return null;
end;


SELECT 
    s.address       адрес,
    r.num_rooms     количество_комнат,
    s.price         цена_покупки,
    r.price         цена_аренды,
    r.price * 12    годовая_аренда,
--round(s.price/s.square, 2) as avg_s,
--round(r.price/(nvl(r.square, s.square)) *12, 2) as avg_r, -- вынести вычисления средних ставок в подзапрос with 
round((round(r.price/(nvl(r.square, s.square))*12, 4)/round(s.price/s.square, 2)), 4)*100||'%' as Ср_ставка_аренды_в_проц
  from (select f2 address,
               mg_to_number(f4) num_rooms,
               listagg(replace(f1, 'www.egsnk.ru/kvartiry/kupit/', ''), ',') within group(order by f1) lnk,
               round(avg(mg_to_number(substr(f5, 1, instr(f5, '/') - 1))), 2) square,
               listagg(f6, ',') within group(order by f1) num_floor,
               round(avg(to_number(f7,
                                   '999G999G999',
                                   'NLS_NUMERIC_CHARACTERS=''. '''))) price
          from student00.realty_sale_data
         where f1 not in
               ('www.egsnk.ru/kvartiry/kupit/id87096629/',
               'www.egsnk.ru/kvartiry/kupit/id87066471/',
               'www.egsnk.ru/kvartiry/kupit/id87137152/',
               'www.egsnk.ru/kvartiry/kupit/id87127137/',
               'www.egsnk.ru/kvartiry/kupit/id87080545/')
         group by f2, mg_to_number(f4)) s,
       (select f2 address,
               mg_to_number(f4) num_rooms,
               listagg(replace(f1, 'www.egsnk.ru/kvartiry/snyat/', ''), ',') within group(order by f1) lnk,
               round(avg(mg_to_number(substr(f5, 1, instr(f5, '/') - 1))), 2) square,
               listagg(f6, ',') within group(order by f1) num_floor,
               round(avg(to_number(f7,
                                   '999G999G999',
                                   'NLS_NUMERIC_CHARACTERS=''. '''))) price
          from student00.realty_rent_data
         group by f2, mg_to_number(f4)
        having mg_to_number(f4) is not null) r
 where s.address = r.address
   and s.num_rooms = r.num_rooms