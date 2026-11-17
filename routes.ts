import { Body, Controller, Get, Inject, Param, Post, Req, Res } from '@nestjs/common';
import type { Principal } from '../../contracts.js';
import type { Management } from '../../management.js';
import { setSensitiveResponseHeaders } from '../kz-common.js';
import { KzValeTrocaService } from './service.js';

type Request = { principal: Principal };
type Response = { setHeader: (name: string, value: string) => void };

@Controller()
export class KzValeTrocaController {
  private readonly svc: KzValeTrocaService;

  constructor(@Inject('MANAGEMENT') management: Management) {
    this.svc = new KzValeTrocaService(management.db);
  }

  @Get('kz/vale-troca/cliente/:id')
  listByCustomer(
    @Req() r: Request,
    @Res({ passthrough: true }) res: Response,
    @Param('id') id: string,
  ) {
    setSensitiveResponseHeaders(res);
    return this.svc.listByCustomer(r.principal, id);
  }

  @Post('kz/vale-troca')
  create(@Req() r: Request, @Body() b: unknown) {
    return this.svc.create(r.principal, b);
  }

  @Post('kz/vale-troca/:id/usar')
  use(@Req() r: Request, @Param('id') id: string, @Body() b: unknown) {
    return this.svc.use(r.principal, id, b);
  }
}
