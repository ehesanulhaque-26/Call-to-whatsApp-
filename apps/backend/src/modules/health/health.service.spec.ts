import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { HealthService } from './health.service';
import { SupabaseService } from '../supabase/supabase.service';
import { OpenWAService } from '../openwa/openwa.service';

describe('HealthService', () => {
  let service: HealthService;

  const mockSupabaseService = {
    query: jest.fn(),
  };

  const mockOpenWAService = {
    healthCheck: jest.fn(),
  };

  const mockConfigService = {
    get: jest.fn().mockReturnValue('test-url'),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        HealthService,
        {
          provide: ConfigService,
          useValue: mockConfigService,
        },
        {
          provide: SupabaseService,
          useValue: mockSupabaseService,
        },
        {
          provide: OpenWAService,
          useValue: mockOpenWAService,
        },
      ],
    }).compile();

    service = module.get<HealthService>(HealthService);

    // Reset mocks before each test
    jest.clearAllMocks();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('getLiveness', () => {
    it('should return alive true', async () => {
      const result = await service.getLiveness();
      expect(result).toEqual({ alive: true });
    });
  });

  describe('getReadiness', () => {
    it('should return ready true when database is up', async () => {
      mockSupabaseService.query.mockResolvedValue([]);
      mockOpenWAService.healthCheck.mockResolvedValue({
        status: 'ok',
        timestamp: new Date().toISOString(),
      });

      const result = await service.getReadiness();

      expect(result).toEqual({ ready: true });
      expect(mockSupabaseService.query).toHaveBeenCalledWith('users', { limit: 1 });
    });

    it('should return ready false when database is down', async () => {
      mockSupabaseService.query.mockRejectedValue(new Error('Connection failed'));

      const result = await service.getReadiness();

      expect(result).toEqual({ ready: false });
    });
  });

  describe('getHealth', () => {
    it('should return healthy status when all services are up', async () => {
      mockSupabaseService.query.mockResolvedValue([]);
      mockOpenWAService.healthCheck.mockResolvedValue({
        status: 'ok',
        timestamp: new Date().toISOString(),
      });

      const result = await service.getHealth();

      expect(result.status).toBe('healthy');
      expect(result.services.database.status).toBe('up');
      expect(result.services.openwa.status).toBe('up');
      expect(result.version).toBe('1.0.0');
      expect(result.timestamp).toBeDefined();
      expect(result.uptime).toBeGreaterThanOrEqual(0);
    });

    it('should return unhealthy status when all services are down', async () => {
      mockSupabaseService.query.mockRejectedValue(new Error('DB Error'));
      mockOpenWAService.healthCheck.mockRejectedValue(new Error('OpenWA Error'));

      const result = await service.getHealth();

      expect(result.status).toBe('unhealthy');
      expect(result.services.database.status).toBe('down');
      expect(result.services.openwa.status).toBe('down');
    });

    it('should return degraded status when some services are down', async () => {
      mockSupabaseService.query.mockResolvedValue([]);
      mockOpenWAService.healthCheck.mockRejectedValue(new Error('OpenWA Error'));

      const result = await service.getHealth();

      expect(result.status).toBe('degraded');
      expect(result.services.database.status).toBe('up');
      expect(result.services.openwa.status).toBe('down');
    });

    it('should include latency for healthy services', async () => {
      mockSupabaseService.query.mockResolvedValue([]);
      mockOpenWAService.healthCheck.mockResolvedValue({
        status: 'ok',
        timestamp: new Date().toISOString(),
      });

      const result = await service.getHealth();

      expect(result.services.database.latency).toBeGreaterThanOrEqual(0);
      expect(result.services.openwa.latency).toBeGreaterThanOrEqual(0);
    });
  });
});
